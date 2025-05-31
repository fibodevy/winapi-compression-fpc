program deflate;

type
  z_streamp = ^z_stream;
  z_stream = record
    next_in   : PByte;   // next input byte
    avail_in  : DWord;   // number of bytes available at next_in
    total_in  : DWord;   // total nb of input bytes read so far
    next_out  : PByte;   // next output byte should be put there
    avail_out : DWord;   // remaining free space at next_out
    total_out : DWord;   // total nb of bytes output so far
    msg       : PByte;   // last error message, NULL if no error
    state     : Pointer; // not visible by applications
    zalloc    : Pointer; // used to allocate the internal state
    zfree     : Pointer; // used to free the internal state
    opaque    : Pointer; // private data object passed to zalloc and zfree
    data_type : Integer; // best guess about the data type: binary or text
    adler     : DWord;   // adler32 value of the uncompressed data
    reserved  : DWord;   // reserved for future use
  end;

const
  Z_FINISH     = 4;
  Z_STREAM_END = 1;
  Z_BUF_ERROR  = -5;

function ums_deflate_init(stream: z_streamp; level: integer; version: pchar; stream_size: integer): integer; stdcall; external 'PresentationNative_v0300.dll';
function ums_deflate(stream: z_streamp; flush: integer): integer; stdcall; external 'PresentationNative_v0300.dll';
function ums_inflate_init(stream: z_streamp; version: pchar; stream_size: integer): integer; stdcall; external 'PresentationNative_v0300.dll';
function ums_inflate(stream: z_streamp; flush: integer): integer; stdcall; external 'PresentationNative_v0300.dll';

function _lopen(lpPathName: PChar; iReadWrite: Integer): THandle; stdcall; external 'kernel32.dll';
function _lread(hFile: THandle; lpBuffer: Pointer; uBytes: Cardinal): Cardinal; stdcall; external 'kernel32.dll';
function _lclose(hFile: THandle): Integer; stdcall; external 'kernel32.dll';
function GetFileSize(hFile: THandle; lpFileSizeHigh: PCardinal): Cardinal; stdcall; external 'kernel32.dll';

function deflate(s: string): string;
var
  z: z_stream;
  e: integer;
begin
  // alloc at least 64 bytes for the output
  if length(s) > 64 then setlength(result, length(s)) else setlength(result, 64);

  z.zalloc := nil;
  z.zfree := nil;
  z.opaque := nil;
  z.avail_in := length(s);
  z.next_in := @s[1];
  z.avail_out := length(result);
  z.next_out := @result[1];

  if ums_deflate_init(@z, 9, '1', sizeof(z)) <> 0 then exit('');

  e := ums_deflate(@z, Z_FINISH);
  if e <> Z_STREAM_END then exit('');

  setlength(result, z.total_out);
end;

function inflate(s: string): string;
var
  z: z_stream;
  e: integer;
begin
  setlength(result, length(s)*2);

  while true do begin
    z.zalloc := nil;
    z.zfree := nil;
    z.opaque := nil;
    z.avail_in := length(s);
    z.next_in := @s[1];
    z.avail_out := length(result);
    z.next_out := @result[1];

    if ums_inflate_init(@z, '1', sizeof(z)) <> 0 then exit('');

    e := ums_inflate(@z, Z_FINISH);
    if e = Z_BUF_ERROR then begin
      // double the buffer
      setlength(result, length(result)*2);
      continue;
    end;
    if e <> Z_STREAM_END then exit('');
    break;
  end;

  setlength(result, z.total_out);
end;

var
  h: thandle;
  original, compressed, decompressed: string;

begin
  // test file
  h := _lopen('C:\Windows\explorer.exe', 0);
  setlength(original, GetFileSize(h, nil));
  _lread(h, @original[1], length(original));
  _lclose(h);
  writeln('original = ':30, length(original));

  // compress
  compressed := deflate(original);
  writeln('compressed = ':30, length(compressed));

  // decompress
  decompressed := inflate(compressed);
  writeln('decompressed = ':30, length(decompressed));

  writeln('decompressed = original? ':30, decompressed=original);
  writeln('compression ratio = ':30, trunc((1-(length(compressed)/length(original)))*100), '%');

  readln;
end.

