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
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls,
  FileUtil, LResources, md5, Process, Registry, ExtCtrls, MaskEdit, Maskutils, Unit2,
  Unit3, httpSend, ssl_openssl, ssl_openssl_lib;

type

  { TForm1 }
  //TForm2 = class(TForm)

  //end;

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
// http://forum.lazarus.freepascal.org/index.php/topic,11659.msg62991.html#msg62991
// http://en.wikipedia.org/wiki/User_Account_Control

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
  VER_SERVER_NT                      = $80000000;
  VER_WORKSTATION_NT                 = $40000000;
  VER_SUITE_SMALLBUSINESS            = $00000001;
  VER_SUITE_ENTERPRISE               = $00000002;
  VER_SUITE_BACKOFFICE               = $00000004;
  VER_SUITE_COMMUNICATIONS           = $00000008;
  VER_SUITE_TERMINAL                 = $00000010;
  VER_SUITE_SMALLBUSINESS_RESTRICTED = $00000020;
  VER_SUITE_EMBEDDEDNT               = $00000040;
  VER_SUITE_DATACENTER               = $00000080;
  VER_SUITE_SINGLEUSERTS             = $00000100;
  VER_SUITE_PERSONAL                 = $00000200;
  VER_SUITE_BLADE                    = $00000400;

  VER_NT_WORKSTATION       = $0000001;
  VER_NT_DOMAIN_CONTROLLER = $0000002;
  VER_NT_SERVER            = $0000003;


procedure TForm1.Button1Click(Sender: TObject);
var
  certificat: string;
  profil_wifi: string;
  profil_soh: string;
  Stream: TLazarusResourceStream;
  tempAdresar: string;
  temp: String;
  rep_temp: string;
  app: TProcess;
  AStringList: TStringList;
  reg: TRegistry;
  windowsVersion: String;
  controlFile: TextFile;
  nactenoZeSouboru: String;
  certificat2: String;
  httpClient: THTTPSend;
  result: String;
  user: String;
  mdp: String;
  osvi: TOSVERSIONINFOEX;
  bOsVersionInfoEx: boolean;
  soh: boolean;
  certificate_client: boolean;
  wifi_client: boolean;
  soh_client: boolean;
  r: TLResource;

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
  if httpClient.HTTPMethod('GET', 'https://packetfence.inverse.ca/winprofil/xml') then
    begin
      httpClient.Document.SaveToFile(rep_temp + 'profil_wifi.xml');
      wifi_client := True;
    end
  else
    begin
      wifi_client := False;
    end;
  httpClient.Free;
  httpClient:= THTTPSend.Create;
  if httpClient.HTTPMethod('GET', 'https://packetfence.inverse.ca/winprofil/ca') then
    begin
      httpClient.Document.SaveToFile(rep_temp + 'certificat.crt');
      certificate_client := True;
    end
  else
    begin
      certificate_client := False;
    end;
  httpClient.Free;
  httpClient:= THTTPSend.Create;
  if httpClient.HTTPMethod('GET', 'https://packetfence.inverse.ca/winprofil/soh') then
    begin
      httpClient.Document.SaveToFile(rep_temp + 'profil_soh.xml');
      soh_client := True;
    end
  else
    begin
      soh_client := False;
    end;
  httpClient.Free;


  //r := LazarusResources.Find('wifi_profil');

  //if r = nil then
  //  wifi_client := False
  //else
  //begin
  //  profil_wifi := LazarusResources.Find('wifi_profil').Value;
  //  wifi_client := True;
  //  Stream := TLazarusResourceStream.Create('profil_wifi', nil);
  //  try
  //    if Stream.Size > 0 then
  //      Stream.SaveToFile(rep_temp + 'profil_wifi.xml');
  //  finally
  //    Stream.Free;
  //  end;
  //end;

  //r := LazarusResources.Find('certificat');

  //if r = nil then
  //  certificate_client := False
  //else
  //begin
  //  certificat := LazarusResources.Find('certificat').Value;
  //  certificate_client := True;
  //  Stream := TLazarusResourceStream.Create('certificat', nil);
  //  try
  //    if Stream.Size > 0 then
  //      Stream.SaveToFile(rep_temp + 'certificat.crt');
  //  finally
  //    Stream.Free;
  //  end;
  //end;


  //r :=  LazarusResources.Find('soh_profil');
  //if r = nil then
  //  soh_client := False
  //else
  //begin
  //  profil_soh :=  LazarusResources.Find('soh_profil').Value;
  //  soh_client := True;
  //  Stream := TLazarusResourceStream.Create('profil_soh', nil);
  //  try
  //    if Stream.Size > 0 then
  //      Stream.SaveToFile(rep_temp + 'profil_soh.xml');
  //  finally
  //  Stream.Free;
  //  end;
  //end;

  //if ( result = '1') then
  //begin
    // windows version superior or equal to Vista
  if wifi_client then
  begin
    if ( osvi.dwMajorVersion >= 6 ) then
    begin
      if certificate_client then
      begin
        app.CommandLine := 'certutil.exe -addstore -f Root "' + rep_temp + 'certificat.crt"';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;
      end;

      //SOH Enable
      if soh_client then
      begin
        app.CommandLine := 'sc config NAPAgent start= auto';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;

        app.CommandLine := 'sc start NAPAgent';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;

        app.CommandLine := 'sc config Dot3Svc start= auto';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;

        app.CommandLine := 'sc start Dot3Svc';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;

        app.CommandLine := 'netsh NAP client import FILENAME = "' + rep_temp + 'profil_soh.xml" ';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;
      end;

      app.CommandLine := 'netsh wlan disconnect';
      app.Options := app.Options + [poWaitOnExit];
      Form1.Visible := False;
      app.Execute;
      Form1.Visible := True;

      app.CommandLine := 'netsh wlan add profile filename="' + rep_temp + 'profil_wifi.xml" ';
      app.Options := app.Options + [poWaitOnExit];
      Form1.Visible := False;
      app.Execute;
      Form1.Visible := True;
    end
    else if ( (windowsVersion = '5.1') or (windowsVersion = '5.2') ) then
    begin
      if certificate_client then
      begin
        // rundll32.exe cryptext.dll,CryptExtAddCER %1
        app.CommandLine := 'rundll32.exe cryptext.dll,CryptExtAddCER ' + rep_temp + 'certificat.crt';
        app.Options := app.Options + [poWaitOnExit];  // cekat na dokonceni programu!
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;
      end;

      //SOH Enable
      if soh_client then
      begin
        app.CommandLine := 'sc config NAPAgent start= auto';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;

        app.CommandLine := 'sc start NAPAgent';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;

        app.CommandLine := 'sc config Dot3Svc start= auto';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;

        app.CommandLine := 'sc start Dot3Svc';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;

        app.CommandLine := 'netsh NAP client import FILENAME = "' + rep_temp + 'profil_soh.xml" ';
        app.Options := app.Options + [poWaitOnExit];
        Form1.Visible := False;
        app.Execute;
        Form1.Visible := True;
      end;

      app.CommandLine := 'netsh wlan disconnect';
      app.Options := app.Options + [poWaitOnExit];
      Form1.Visible := False;
      app.Execute;
      Form1.Visible := True;

      app.CommandLine := 'netsh wlan add profile filename="' + rep_temp + 'profil_wifi.xml" ';
      app.Options := app.Options + [poWaitOnExit];
      Form1.Visible := False;
      app.Execute;
      Form1.Visible := True;
    end;

    app.CommandLine := 'netsh wlan show profiles';
    AStringList := TStringList.Create;
    AStringList.TextLineBreakStyle := tlbsCRLF;
    app.Options := app.Options + [poWaitOnExit, poUsePipes];
    app.Execute;
    Form2.Visible := True;
    AStringList.LoadFromStream(app.Output);
    Form2.Memo1.Lines := AStringList;
    AStringList.Free;

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

