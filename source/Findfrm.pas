{
    This file is part of Dev-C++
    Copyright (c) 2004 Bloodshed Software

    Dev-C++ is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Dev-C++ is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Dev-C++; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit FindFrm;

interface

uses
{$IFDEF WIN32}
  Windows, Messages, editor, SysUtils, Classes, Graphics, Controls, Forms,
  SynEdit, StdCtrls, SynEditTypes, SynEditSearch, ComCtrls;
{$ENDIF}
{$IFDEF LINUX}
  SysUtils, Classes, QGraphics, QControls, QForms,
  QSynEdit, QStdCtrls, QSynEditTypes;
{$ENDIF}

type
  TfrmFind = class(TForm)
    btnFind: TButton;
    btnCancel: TButton;
    FindTabs: TTabControl;
    lblFind: TLabel;
    cboFindText: TComboBox;
    grpOptions: TGroupBox;
    cbMatchCase: TCheckBox;
    cbWholeWord: TCheckBox;
    grpDirection: TGroupBox;
    rbForward: TRadioButton;
    rbBackward: TRadioButton;
    grpScope: TGroupBox;
    rbGlobal: TRadioButton;
    rbSelectedOnly: TRadioButton;
    grpOrigin: TGroupBox;
    rbFromCursor: TRadioButton;
    rbEntireScope: TRadioButton;
    grpWhere: TGroupBox;
    rbProjectFiles: TRadioButton;
    rbOpenFIles: TRadioButton;
    cbPrompt: TCheckBox;
    cboReplaceText: TComboBox;
    lblReplace: TLabel;
    procedure btnFindClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnCancelClick(Sender: TObject);
    procedure FindTabsChange(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    fSearchOptions : TSynSearchOptions;
    fCurFile : AnsiString;
    fTabIndex : integer;
    fEditor : TEditor;
    fSearchEngine : TSynEditSearch;
    fTempSynEdit : TSynEdit;
    procedure LoadText;
    procedure CustomOnReplace(Sender: TObject; const aSearch,aReplace: AnsiString; Line, Column: integer; var Action: TSynReplaceAction);
    procedure FindReplaceFirst(editor : TSynEdit);
    procedure FindReplaceFiles(editor : TSynEdit;isreplace : boolean);
  public
    property SearchOptions : TSynSearchOptions read fSearchOptions;
    property TabIndex : integer read fTabIndex write fTabIndex;
  end;

var
 frmFind: TfrmFind;

implementation

uses 
{$IFDEF WIN32}
  Main, Dialogs, MultiLangSupport, devcfg;
{$ENDIF}
{$IFDEF LINUX}
  Xlib, Main, QDialogs, MultiLangSupport, devcfg;
{$ENDIF}

{$R *.dfm}

procedure TfrmFind.FindReplaceFirst(editor : TSynEdit);
begin
	editor.SearchEngine := fSearchEngine;
	if(editor.SearchReplace(cboFindText.Text,cboReplaceText.Text,fSearchOptions) = 0) then
		MessageBox(Application.Handle,PChar(format(Lang[ID_MSG_TEXTNOTFOUND], [cboFindText.Text])),PChar('Info'),MB_ICONINFORMATION);
	editor.SearchEngine := nil;
end;

procedure TfrmFind.FindReplaceFiles(editor : TSynEdit;isreplace : boolean);
var
	caretbackup : TBufferCoord;
	onreplacebackup : TReplaceTextEvent;
begin
	caretbackup := editor.CaretXY;
	onreplacebackup := editor.OnReplaceText;

	// Don't skip when replacing!
	if not isreplace then
		editor.OnReplaceText := CustomOnReplace;

	editor.SearchEngine := fSearchEngine;
	editor.SearchReplace(cboFindText.Text,cboReplaceText.Text,fSearchOptions);
	editor.SearchEngine := nil;

	editor.CaretXY := caretbackup;
	editor.OnReplaceText := onreplacebackup;
end;

procedure TfrmFind.btnFindClick(Sender: TObject);
var
	isfind,isfindfiles,isreplace,isreplacefiles : boolean;
	I : integer;
begin
	if cboFindText.Text = '' then Exit;

	// Assemble search options
	isfind := (FindTabs.TabIndex = 0);
	isfindfiles := (FindTabs.TabIndex = 1);
	isreplace := (FindTabs.TabIndex = 2);
	isreplacefiles := (FindTabs.TabIndex = 3);

	cboFindText.AddItem(cboFindText.Text,nil);

	if (isreplace or isreplacefiles) and (cboReplaceText.Text <> '') then
		cboReplaceText.AddItem(cboReplaceText.Text,nil);

	fSearchOptions := [];

	if cbMatchCase.Checked then
		Include(fSearchOptions,ssoMatchCase);
	if cbWholeWord.Checked then
		Include(fSearchOptions,ssoWholeWord);
	if cbPrompt.Checked or isfindfiles then
		Include(fSearchOptions,ssoPrompt); // do a fake prompted replace when using find in files

	if rbBackward.Checked then
		Include(fSearchOptions,ssoBackwards);

	if rbEntireScope.Checked or isfindfiles or isreplacefiles then
		Include(fSearchOptions,ssoEntireScope);

	if rbSelectedOnly.Checked then
		Include(fSearchOptions,ssoSelectedOnly);

	if isreplace or isreplacefiles or isfindfiles then
		Include(fSearchOptions,ssoReplace); // do a fake prompted replace when using find in files

	if isfindfiles or isreplace or isreplacefiles then
		Include(fSearchOptions,ssoReplaceAll);

	if isfind or isreplace then begin
		fEditor := MainForm.GetEditor;

		FindReplaceFirst(fEditor.Text);
	end;

	// Do the actual searching
	if isfindfiles or isreplacefiles then begin

		if isfindfiles then
			MainForm.FindOutput.Clear;

		// loop through pagecontrol
		if rbOpenFiles.Checked then begin

			// loop through editors, add results to message control
			for I := 0 to MainForm.PageControl.PageCount - 1 do begin
				fEditor := MainForm.GetEditor(i);
				fCurFile := fEditor.FileName;

				fEditor.Activate;

				FindReplaceFiles(fEditor.Text,isreplacefiles);
			end;

		// loop through project
		end else begin
			for I := 0 to MainForm.fProject.Units.Count - 1 do begin
				fEditor := MainForm.fProject.Units[i].Editor;
				fCurFile := MainForm.fProject.Units[i].FileName;

				// file is already open, use memory
				if Assigned(fEditor) then begin
					fEditor.Activate;

					FindReplaceFiles(fEditor.Text,isreplacefiles);

				// not open? load from disk
				end else begin
					fTempSynEdit.Lines.LoadFromFile(fCurFile);

					FindReplaceFiles(fTempSynEdit,isreplacefiles);
				end;
			end;
		end;

		if isfindfiles then begin
			MainForm.MessageControl.ActivePageIndex := 4; // Find Tab
			MainForm.OpenCloseMessageSheet(TRUE);
		end;
	end;
end;

procedure TfrmFind.CustomOnReplace(Sender: TObject;const aSearch, aReplace: AnsiString; Line, Column: integer;var Action: TSynReplaceAction);
begin
	MainForm.AddFindOutputItem(IntToStr(Line),IntToStr(Column),fCurFile,TCustomSynEdit(Sender).Lines[Line-1]);
	action := raSkip;
end;

procedure TfrmFind.FormClose(Sender: TObject; var Action: TCloseAction);
begin
	fSearchEngine.Free;
	fTempSynEdit.Free;
	Action := caFree;
	frmFind := nil;
end;

procedure TfrmFind.btnCancelClick(Sender: TObject);
begin
	Close;
end;

procedure TfrmFind.FindTabsChange(Sender: TObject);
var
	isfind,isfindfiles,isreplace,isreplacefiles : boolean;
begin
	isfind := (FindTabs.TabIndex = 0);
	isfindfiles := (FindTabs.TabIndex = 1);
	isreplace := (FindTabs.TabIndex = 2);
	isreplacefiles := (FindTabs.TabIndex = 3);

	lblReplace.Visible := isreplace or isreplacefiles;
	cboReplaceText.Visible := isreplace or isreplacefiles;

	grpDirection.Visible := isfind or isreplace;
	grpOrigin.Visible := isfind or isreplace;
	grpScope.Visible := isfind or isreplace;
	grpWhere.Visible := isfindfiles or isreplacefiles;
	// grpOption is always visible

	// Disable project search option when none is open
	rbProjectFiles.Enabled := Assigned(MainForm.fProject) and not isreplacefiles;
	if not Assigned(MainForm.fProject) or isreplacefiles then
		rbOpenFiles.Checked := true; // only apply when branch is taken!

	// Disable prompt when doing finds
	cbPrompt.Enabled := isreplace or isreplacefiles;

	if not isreplace and not isreplacefiles then begin
		Caption := Lang[ID_FIND_FINDTAB];
		btnFind.Caption := Lang[ID_BTN_FIND]
	end else begin
		Caption := Lang[ID_FIND_REPLACE];
		btnFind.Caption := Lang[ID_BTN_REPLACE];
	end;
end;

procedure TfrmFind.LoadText;
begin
	// Set interface font
	Font.Name := devData.InterfaceFont;
	Font.Size := devData.InterfaceFontSize;

  Caption:=                 Lang[ID_FIND];

  //tabs
  FindTabs.Tabs.Clear;
  FindTabs.Tabs.Add(Lang[ID_FIND_FINDTAB]);
  FindTabs.Tabs.Add(Lang[ID_FIND_FINDALLTAB]);
  FindTabs.Tabs.Add(Lang[ID_FIND_REPLACE]);
  FindTabs.Tabs.Add(Lang[ID_FIND_REPLACEFILES]);

  //controls
  lblFind.Caption:=        Lang[ID_FIND_TEXT];
  lblReplace.Caption:=     Lang[ID_FIND_REPLACEWITH];
  grpOptions.Caption:=     '  '+Lang[ID_FIND_GRP_OPTIONS] +'  ';
  cbMatchCase.Caption:=    Lang[ID_FIND_CASE];
  cbWholeWord.Caption:=    Lang[ID_FIND_WWORD];
  cbPrompt.Caption:=       Lang[ID_FIND_PROMPTREPLACE];

  grpWhere.Caption:=       Lang[ID_FIND_GRP_WHERE];
  rbProjectFiles.Caption:= Lang[ID_FIND_PRJFILES];
  rbOpenFIles.Caption:=    Lang[ID_FIND_OPENFILES];

  grpScope.Caption:=       '  ' +Lang[ID_FIND_GRP_SCOPE] +'  ';
  rbGlobal.Caption:=       Lang[ID_FIND_GLOBAL];
  rbSelectedOnly.Caption:= Lang[ID_FIND_SELONLY];

  grpOrigin.Caption:=      '  ' +Lang[ID_FIND_GRP_ORIGIN] +'  ';
  rbFromCursor.Caption:=   Lang[ID_FIND_CURSOR];
  rbEntireScope.Caption:=  Lang[ID_FIND_ENTIRE];

  grpDirection.Caption:=   '  ' +Lang[ID_FIND_GRP_DIRECTION] +'  ';
  rbForward.Caption:=      Lang[ID_FIND_FORE];
  rbBackward.Caption:=     Lang[ID_FIND_BACK];

  //buttons
  btnFind.Caption:=        Lang[ID_BTN_FIND];
  btnCancel.Caption:=      Lang[ID_BTN_CANCEL];
end;

procedure TfrmFind.FormKeyDown(Sender: TObject; var Key: Word;Shift: TShiftState);
begin
{$IFDEF WIN32}
	if (Key=VK_TAB) and (Shift=[ssCtrl]) then
{$ENDIF}
{$IFDEF LINUX}
	if (Key=XK_TAB) and (Shift=[ssCtrl]) then
{$ENDIF}
		// eliminated a branch! :D
		FindTabs.TabIndex := (FindTabs.TabIndex+1) mod 4;
end;

procedure TfrmFind.FormCreate(Sender: TObject);
begin
	LoadText;
	ActiveControl := cboFindText;

	// TODO: weird stuff
	fSearchEngine := TSynEditSearch.Create(Self);
	fTempSynEdit := TSynEdit.Create(Self);
end;

procedure TfrmFind.FormShow(Sender: TObject);
begin
	FindTabs.TabIndex := fTabIndex;
	FindTabsChange(nil);
end;

end.
