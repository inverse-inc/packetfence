{
 *******************************************************************************
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License, Version 1.0 only.
 *
 * You can obtain a copy of the license at
 * license.txt
 * or http://www.opensource.org/licenses/CDDL-1.0
 *
 * Copyright (c) 2011, Martin Vancl. All rights reserved.
 * http://code.google.com/p/wifi-wpa-enterprise-configurator/
 *******************************************************************************
}

unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls,
  FileUtil, LResources, md5, Process, Registry, ExtCtrls, Unit2,
  Unit3, httpSend, ssl_openssl, ssl_openssl_lib, ShellApi;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}
{$R manifest.rc}

{ TForm1 }
type
  TOSVERSIONINFOEX = record
    dwOSVersionInfoSize: DWORD;
    dwMajorVersion: DWORD;
    dwMinorVersion: DWORD;
    dwBuildNumber: DWORD;
    dwPlatformId: DWORD;
    szCSDVersion: array[0..127] of AnsiChar; { Maintenance string for PSS usage }
    wServicePackMajor: WORD;
    wServicePackMinor: WORD;
    wSuiteMask: WORD;
    wProductType: BYTE;
    wReserved: BYTE;
  end;

const
  VER_NT_WORKSTATION       = $0000001;

function ShellExecAndWait(const FileName, Parameters, dir: string;
  CmdShow: Integer): Boolean;
var
  Sei: TShellExecuteInfo;
begin
  FillChar(Sei, SizeOf(Sei), #0);
  Sei.cbSize := SizeOf(Sei);
  Sei.fMask := SEE_MASK_DOENVSUBST or SEE_MASK_FLAG_NO_UI or SEE_MASK_NOCLOSEPROCESS;
  Sei.lpFile := PChar(FileName);
  Sei.lpParameters := PChar(Parameters);
  Sei.lpdirectory := PChar(dir);
  Sei.nShow := CmdShow;
  Result := ShellExecuteExA(@Sei);
  if Result then
  begin
    WaitForInputIdle(Sei.hProcess, INFINITE);
    WaitForSingleObject(Sei.hProcess, INFINITE);
    CloseHandle(Sei.hProcess);
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  soh: boolean;
  certificate_client: boolean;
  wifi_client: boolean;
  soh_client: boolean;
  tempAdresar: string;
  temp: String;
  rep_temp: string;
  app: TProcess;
  AStringList: TStringList;
  windowsVersion: String;
  httpClient: THTTPSend;
  osvi: TOSVERSIONINFOEX;
  bOsVersionInfoEx: boolean;
  Registry: TRegistry;


begin
  app := TProcess.Create(nil);
  FillChar(osvi, SizeOf(TOSVERSIONINFOEX), 0);
  osvi.dwOSVersionInfoSize:= SizeOf(TOSVERSIONINFOEX);

  // Determine Windows Version
  bOsVersionInfoEx:= GetVersionEx(POSVERSIONINFO(@osvi)^);
  if not bOsVersionInfoEx then
  begin
    osvi.dwOSVersionInfoSize:= SizeOf(TOSVERSIONINFO);
    if not GetVersionEx(POSVERSIONINFO(@osvi)^) then
      exit;
  end;

    case osvi.dwPlatformId of
      VER_PLATFORM_WIN32_NT:
      begin
        Label3.Caption := 'Windows XP SP3';
        if osvi.wProductType = VER_NT_WORKSTATION then
        begin
          if (osvi.dwMajorVersion = 5) and (osvi.dwMinorVersion = 1) and (osvi.wServicePackMajor = 3) then
          begin
            Label3.Caption := 'Windows XP SP3';
            soh := True;
          end;
          if (osvi.dwMajorVersion = 5) and (osvi.dwMinorVersion = 2) and (osvi.wServicePackMajor = 3) then
          begin
            Label3.Caption := 'Windows XP X86_64 SP3';
            soh := True;
          end;
          if (osvi.dwMajorVersion >= 6) then
          begin
            Label3.Caption := 'Windows Vista or Windows 7 or Windows 8';
            soh := True;
          end;
        end;
      end;
    else
      Label3.Caption := 'Unsupported Windows Version';
    end;

  //Set the current windows version
  windowsVersion := IntToStr(osvi.dwMajorVersion) + '.' + IntToStr(osvi.dwMinorVersion);

  Randomize;
  tempAdresar := MD5Print(MD5String(IntToStr(Random(999))));

  temp := GetTempDir();

  If Not DirectoryExists(temp + tempAdresar) then
  begin
     If Not CreateDir (temp + tempAdresar) Then
       begin
        //Label1.Caption := 'Failed to create directory !';
       end
     else
       begin
         //Label1.Caption := 'Created TEMP directory';
       end
  end;

  rep_temp := temp + tempAdresar + '\';

  // Generate files to create the wifi, certificate and soh profil
  httpClient:= THTTPSend.Create;
  httpClient.Sock.SSL.VerifyCert:=false;
  if httpClient.HTTPMethod('GET', 'http://provisioning.inverse.ca/winprofil/xml') then
    begin
      case httpClient.ResultCode of
        100..299:
          begin
            httpClient.Document.SaveToFile(rep_temp + 'profil_wifi.xml');
            wifi_client := True;
          end;
        300..399: wifi_client:=false; //redirection. Not implemented, but could be.
        400..499: wifi_client:=false; //client error; 404 not found etc
        500..599: wifi_client:=false; //internal server error
        else wifi_client:=false; //unknown code
      end
    end
  else
    begin
      wifi_client := False;
    end;
  httpClient.Free;

  httpClient:= THTTPSend.Create;
  httpClient.Sock.SSL.VerifyCert:=false;
  if httpClient.HTTPMethod('GET', 'http://provisioning.inverse.ca/winprofil/ca') then
    begin
      case httpClient.ResultCode of
        100..299:
          begin
            httpClient.Document.SaveToFile(rep_temp + 'certificat.crt');
            certificate_client := True;
          end;
        300..399: certificate_client:=false; //redirection. Not implemented, but could be.
        400..499: certificate_client:=false; //client error; 404 not found etc
        500..599: certificate_client:=false; //internal server error
        else certificate_client:=false; //unknown code
      end
    end
  else
    begin
      certificate_client := False;
    end;
  httpClient.Free;

  httpClient:= THTTPSend.Create;
  httpClient.Sock.SSL.VerifyCert:=false;
  if httpClient.HTTPMethod('GET', 'http://provisioning.inverse.ca/winprofil/soh') then
    begin
      case httpClient.ResultCode of
        100..299:
          begin
            httpClient.Document.SaveToFile(rep_temp + 'profil_soh.xml');
            soh_client := True;
          end;
        300..399: soh_client:=false; //redirection. Not implemented, but could be.
        400..499: soh_client:=false; //client error; 404 not found etc
        500..599: soh_client:=false; //internal server error
        else soh_client:=false; //unknown code
      end
    end
  else
    begin
      soh_client := False;
    end;
  httpClient.Free;

  if wifi_client then
  begin
      Registry := TRegistry.Create;
      try
        // Navigate to proper "directory":
        Registry.RootKey := HKEY_LOCAL_MACHINE;
        if Registry.OpenKey('\SYSTEM\CurrentControlSet\services\RasMan\PPP\EAP\25',True) then
          if Registry.ValueExists('PathBackup') then
          begin
            Registry.RenameValue('Path','Path_bak');
            Registry.RenameValue('PathBackup','Path');
            Registry.RenameValue('InteractiveUIPath','InteractiveUIPath_bak');
            Registry.RenameValue('InteractiveUIPathBackup','InteractiveUIPath');
            Registry.RenameValue('ConfigUiPath','ConfigUiPath_bak');
            Registry.RenameValue('ConfigUiPathBackup','ConfigUiPath');
            Registry.RenameValue('IdentityPath','IdentityPath_bak');
            Registry.RenameValue('IdentityPathBackup','IdentityPath');
          end;
      finally
        Registry.Free;
      end;
    if ( osvi.dwMajorVersion >= 6 ) then
    begin
      if certificate_client then
      begin
        ShellExecAndWait('certutil.exe', ' -addstore -f Root "' + rep_temp + 'certificat.crt"', '',0);
      end;

      //SOH Enable
      if soh_client then
      begin
        ShellExecAndWait('sc',' config NAPAgent start= auto', '',0);
        ShellExecAndWait('sc',' start NAPAgent', '',0);
        ShellExecAndWait('sc',' config Dot3Svc start= auto', '',0);
        ShellExecAndWait('sc',' start Dot3Svc', '',0);
        ShellExecAndWait('netsh',' NAP client import FILENAME = "' + rep_temp + 'profil_soh.xml" ', '',0);
      end;
      ShellExecAndWait('netsh',' wlan disconnect', '',0);
      ShellExecAndWait('netsh',' wlan add profile filename="' + rep_temp + 'profil_wifi.xml" user=current', '',0);
    end
    else if ( (windowsVersion = '5.1') or (windowsVersion = '5.2') ) then
    begin
      if certificate_client then
      begin
        ShellExecAndWait('rundll32.exe',' cryptext.dll,CryptExtAddCER ' + rep_temp + 'certificat.crt', '',0);
      end;

      //SOH Enable
      if soh_client then
      begin
        ShellExecAndWait('sc',' config NAPAgent start= auto', '',0);
        ShellExecAndWait('sc',' start NAPAgent', '',0);
        ShellExecAndWait('sc',' config Dot3Svc start= auto', '',0);
        ShellExecAndWait('sc',' start Dot3Svc', '',0);
        ShellExecAndWait('netsh',' NAP client import FILENAME = "' + rep_temp + 'profil_soh.xml" ', '',0);
      end;
      ShellExecAndWait('netsh',' wlan disconnect', '',0);
      ShellExecAndWait('netsh',' wlan add profile filename="' + rep_temp + 'profil_wifi.xml" ', '',0);
    end;
    try
      Registry := TRegistry.Create;
      // Navigate to proper "directory":
      Registry.RootKey := HKEY_LOCAL_MACHINE;
      if Registry.OpenKey('\SYSTEM\CurrentControlSet\services\RasMan\PPP\EAP\25',True) then
        if Registry.ValueExists('Path_bak') then
        begin
          Registry.RenameValue('Path','PathBackup');
          Registry.RenameValue('Path_bak','Path');
          Registry.RenameValue('InteractiveUIPath','InteractiveUIPathBackup');
          Registry.RenameValue('InteractiveUIPath_bak','InteractiveUIPath');
          Registry.RenameValue('ConfigUiPath','ConfigUiPathBackup');
          Registry.RenameValue('ConfigUiPath_bak','ConfigUiPath');
          Registry.RenameValue('IdentityPath','IdentityPathBackup');
          Registry.RenameValue('IdentityPath_bak','IdentityPath');
        end;
    finally
      Registry.Free;
    end;
  end
  else
  begin
    Form3.Visible := True;
  end;

//  DeleteFile (rep_temp + 'certificat.crt');
//  DeleteFile (rep_temp + 'profil_wifi.xml');
//  RemoveDir (rep_temp);

  app.free;



end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  Application.terminate;
end;





initialization


end.

