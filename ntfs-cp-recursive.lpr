// -*- compile-command: "fpc ntfs-cp-recursive.lpr" -*-
{
  Copyright 2020-2020 Michalis Kamburelis.

  This file is part of "ntfs-cp-recursive".

  "ntfs-cp-recursive" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "ntfs-cp-recursive" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}
{ Copy a directory recursively using ntfs-3g tools. }

{$mode objfpc}{$H+}{$J-}

uses SysUtils, Classes, Process, StrUtils;

var
  Device, Path: String;
  DryRun: Boolean;
  Depth: Integer = -1;
  Exclude: TStringList;

{ Simple parsing of command-line arguments, specific to this tool.
  Hint: for a more generic way to handle command-line arguments,
  consider using Castle Game Engine CastleParameters unit.
  But I wanted to keep this tool simple, without extra dependencies. }
procedure ParseCommandLine;
var
  I, RequiredParameterIndex: Integer;
begin
  I := 1;
  RequiredParameterIndex := 1;
  while I <= ParamCount do
  begin
    if ParamStr(I) = '--depth' then
    begin
      Inc(I);
      if I > ParamCount then
        raise Exception.Create('--depth requires an argument');
      Depth := StrToInt(ParamStr(I));
      Inc(I);
    end else
    if ParamStr(I) = '--exclude' then
    begin
      Inc(I);
      if I > ParamCount then
        raise Exception.Create('--exclude requires an argument');
      Exclude.Add(ParamStr(I));
      Inc(I);
    end else
    if ParamStr(I) = '--dry-run' then
    begin
      DryRun := true;
      Inc(I);
    end else
    case RequiredParameterIndex of
      1:begin
          Device := ParamStr(I);
          Inc(I);
          Inc(RequiredParameterIndex);
        end;
      2:begin
          Path := ParamStr(I);
          Inc(I);
          Inc(RequiredParameterIndex);
        end;
      else raise Exception.CreateFmt('Too many command-line parameters: "%s"', [ParamStr(I)]);
    end;
  end;
  if RequiredParameterIndex <> 3 then
    raise Exception.Create('Not enough command-line parameters, required DEVICE PATH parameters');
end;

{ Glue strings using a delimiter.
  Hint: Castle Game Engine has this in CastleStringUtils unit. }
function GlueStrings(const Strings: array of String; const Delimiter: Char): String;
var
  I: Integer;
begin
  if High(Strings) = -1 then
    Exit('');
  Result := Strings[0];
  for I := 1 to High(Strings) do
    Result := Result + Delimiter + Strings[I];
end;

type
  ECommandError = class(Exception);

{ Run given command, capturing standard output to a String. }
function RunCommandEasily(const ExeName: String; const Arguments: array of String): String;
var
  Exe: String;
begin
  Exe := ExeSearch(ExeName);
  if Exe = '' then
    raise Exception.CreateFmt('Cannot find "%s" tool', [ExeName]);
  if not RunCommand(Exe, Arguments, Result) then
    raise ECommandError.CreateFmt('Failed to execute "%s" with arguments [%s]', [
      Exe,
      GlueStrings(Arguments, ' ')
    ]);
end;

{ List directory contents using ntfsls. }
function ListDirectory(const Path: String): TStringList;
begin
  Result := TStringList.Create;
  Result.Text := RunCommandEasily('ntfsls',
    ['--all', '--system', '--classify', '--force', Device, '--path', Path]);
end;

type
  TEntryType = (
    etRegular,
    etExecutable,
    etDirectory,
    etSocket,
    etSymbolicLink,
    etPipe
  );

{ Understand ntfsls suffix produced by --classify.
  It's similar to ls suffixes: https://unix.stackexchange.com/questions/82357/what-do-the-symbols-displayed-by-ls-f-mean . }
function ExtractClassifier(const S: String; out EntryType: TEntryType): String;
const
  Suffixes: array [TEntryType] of Char = (#0, '*', '/', '=', '@', '|');
var
  Len: Integer;
  E: TEntryType;
begin
  if S = '' then
    Exit('');
  Len := Length(S);

  for E := Succ(Low(TEntryType)) to High(TEntryType) do
    if S[Len] = Suffixes[E] then
    begin
      Result := Copy(S, 1, Len - 1);
      EntryType := E;
      Exit;
    end;

  // if no suffix matched, it's etRegular
  Result := S;
  EntryType := etRegular;
end;

{ Write file with given contents.

  This should not be used for binary files, as we're abusing Strings a bit,
  but in practice it works (and there should not be any UTF8<>xxx conversion
  between RunCommand and StringToFile, as on Linux everything is assumed
  UTF8 always).

  Hint: Castle Game Engine has this in CastleFilesUtils unit, and accepting also URLs. }
procedure StringToFile(const FileName: String; const Contents: String);
var
  F: TStream;
begin
  F := TFileStream.Create(FileName, fmCreate);
  try
    if Length(Contents) <> 0 then
      F.WriteBuffer(Contents[1], Length(Contents));
  finally FreeAndNil(F) end;
end;

{ Use ntfscat to copy file. }
procedure CopyFile(const Path, OutputPath: String);
var
  FileContents: String;
begin
  Writeln('Copying ', Path, ' -> ', OutputPath);
  if not DryRun then
  try
    FileContents := RunCommandEasily('ntfscat', ['--force', Device, Path]);
    StringToFile(OutputPath, FileContents);
  except
    on E: ECommandError do
      Writeln('Failed to read file, aborting: ', E.Message);
  end;
end;

{ Create directory, unless it already exists. }
procedure CreateOutputDirectory(const OutputPath: String);
begin
  if (not DryRun) and
     (not DirectoryExists(OutputPath)) and
     (not CreateDir(OutputPath)) then
    raise Exception.CreateFmt('Cannot create directory "%s"', [OutputPath]);
end;

{ Does given argument S match any mask in Exclude list. }
function IsExcluded(const S: String): Boolean;
var
  Mask: String;
begin
  for Mask in Exclude do
    if IsWild(S, Mask, true) then
      Exit(true);
  Result := false;
end;

{ Process given Path, at given CurrentDepth.
  Note that Path local parameter here obscures global Path variable. }
procedure ProcessDirectory(const Path: String; const CurrentDepth: Integer;
  const OutputPathParent: String);
var
  Contents: TStringList;
  EntryName, S, OutputPath, LastPathComponent: String;
  EntryType: TEntryType;
begin
  if (Depth >= 0) and (CurrentDepth > Depth) then
  begin
    Writeln('Ignoring ', Path, ', too deep');
    Exit;
  end;

  LastPathComponent := ExtractFileName(Path);
  if OutputPathParent <> '' then
    OutputPath := OutputPathParent + '/' + LastPathComponent
  else
    OutputPath := LastPathComponent;
  Writeln('Creating output directory ', OutputPath);
  CreateOutputDirectory(OutputPath);

  try
    Contents := ListDirectory(Path);
  except
    on E: ECommandError do
    begin
      Writeln('Failed to read directory, aborting: ', E.Message);
      Exit;
    end;
  end;

  try
    for S in Contents do
    begin
      EntryName := ExtractClassifier(S, EntryType);
      if (EntryName <> '.') and
         (EntryName <> '..') then
      begin
        if IsExcluded(EntryName) then
          Writeln('Ignoring excluded: ', Path + '/' + EntryName)
        else
        if EntryType = etDirectory then
          ProcessDirectory(Path + '/' + EntryName, CurrentDepth + 1,  OutputPath)
        else
          CopyFile(Path + '/' + EntryName, OutputPath + '/' + EntryName);
      end;
    end;
  finally FreeAndNil(Contents) end;
end;

var
  FixedPath: String;
begin
  Exclude := TStringList.Create;
  try
    ParseCommandLine;

    // FixedPath is like Path, but without backslashes, and without trailing slash/backslash
    FixedPath := StringReplace(Path, '\', '/', [rfReplaceAll]);
    if (FixedPath <> '') and
       (FixedPath[Length(FixedPath)] = '/') then
      FixedPath := Copy(FixedPath, 1, Length(FixedPath) - 1);

    ProcessDirectory(FixedPath, 0, '');
  finally FreeAndNil(Exclude) end;
end.
