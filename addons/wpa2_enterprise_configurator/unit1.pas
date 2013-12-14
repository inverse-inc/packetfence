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

function RunAsAdmin(const Handle: Hwnd; const Path, Params: string): Boolean;
var
  sei: TShellExecuteInfoA;
begin
  FillChar(sei, SizeOf(sei), 0);
  sei.cbSize := SizeOf(sei);
  sei.Wnd := Handle;
  sei.fMask := SEE_MASK_FLAG_DDEWAIT or SEE_MASK_FLAG_NO_UI;
  sei.lpVerb := 'runas';
  sei.lpFile := PAnsiChar(Path);
  sei.lpParameters := PAnsiChar(Params);
  sei.nShow := SW_SHOWNORMAL;
  Result := ShellExecuteExA(@sei);
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
  if httpClient.HTTPMethod('GET', 'https://provisioning.inverse.ca/winprofil/xml') then
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
  if httpClient.HTTPMethod('GET', 'https://provisioning.inverse.ca/winprofil/ca') then
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
  if httpClient.HTTPMethod('GET', 'https://provisioning.inverse.ca/winprofil/soh') then
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
    if ( osvi.dwMajorVersion >= 6 ) then
    begin
      if certificate_client then
      begin
        RunAsAdmin(Form1.Handle, 'certutil.exe -addstore -f Root "' + rep_temp + 'certificat.crt"', '');
      end;

      //SOH Enable
      if soh_client then
      begin
        RunAsAdmin(Form1.Handle, 'sc config NAPAgent start= auto', '');
        RunAsAdmin(Form1.Handle, 'sc start NAPAgent', '');
        RunAsAdmin(Form1.Handle, 'sc config Dot3Svc start= auto', '');
        RunAsAdmin(Form1.Handle, 'sc start Dot3Svc', '');
        RunAsAdmin(Form1.Handle, 'netsh NAP client import FILENAME = "' + rep_temp + 'profil_soh.xml" ', '');
      end;
      RunAsAdmin(Form1.Handle, 'netsh wlan disconnect', '');
      RunAsAdmin(Form1.Handle, 'netsh wlan add profile filename="' + rep_temp + 'profil_wifi.xml" user=current', '');
    end
    else if ( (windowsVersion = '5.1') or (windowsVersion = '5.2') ) then
    begin
      if certificate_client then
      begin
        RunAsAdmin(Form1.Handle, 'rundll32.exe cryptext.dll,CryptExtAddCER ' + rep_temp + 'certificat.crt', '');
      end;

      //SOH Enable
      if soh_client then
      begin
        RunAsAdmin(Form1.Handle, 'sc config NAPAgent start= auto', '');
        RunAsAdmin(Form1.Handle, 'sc start NAPAgent', '');
        RunAsAdmin(Form1.Handle, 'sc config Dot3Svc start= auto', '');
        RunAsAdmin(Form1.Handle, 'sc start Dot3Svc', '');
        RunAsAdmin(Form1.Handle, 'netsh NAP client import FILENAME = "' + rep_temp + 'profil_soh.xml" ', '');
      end;
      RunAsAdmin(Form1.Handle, 'netsh wlan disconnect', '');
      RunAsAdmin(Form1.Handle, 'netsh wlan add profile filename="' + rep_temp + 'profil_wifi.xml" user=current', '');
    end;
    RunAsAdmin(Form1.Handle, 'netsh wlan show profiles', '');
  end
  else
  begin
     Form3.Visible := True;
  end;

//  DeleteFile (rep_temp + 'certificat.crt');
//  DeleteFile (rep_temp + 'profil_wifi.xml');
  RemoveDir (rep_temp);

  app.free;



end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  Application.terminate;
end;





initialization


end.

