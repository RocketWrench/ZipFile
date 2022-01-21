function varargout = getZipFileContents( zipFile, pattern, excludeDirectories, asURL )

    narginchk(1,4);
    
    nargoutchk(0,2);
    
    switch nargin
        
        case 1
            pattern = [];
            excludeDirectories = false;
            asURL = false;            
        case 2
            excludeDirectories = false;
            asURL = false;
        case 3
            asURL = false;            
    end
    % Open the file for reading
    fid = fopen(zipFile,'r');

    if fid < 3
       error('getZipContents:badFile','Cannot read %s',zipFile) 
    end
    
    cleanUp = onCleanup(@()fclose(fid));

    if ~isSig( fread(fid,[1,4],'*uint8'), 'lfh' )
       error('getZipContents:badLFH','File does not start with a local file header signature\nMost likely it is a self-exctracting zip file') 
    end

    noEntries = positionAtCentralDirectoryRecord( fid );
    
    if isempty(noEntries)
        entries = populateFromZip64CenteralDirectory( fid );
    else
        entries = populateFromCenteralDirectory( fid, noEntries );
    end
    
    % TODO: Check validity of entries
    content = {entries(:).FileName}';
    
    if ~isempty(pattern)        
        content = content(contains(content,pattern));
    end
    
    if excludeDirectories       
        content = content(~endsWith(content,'/'));
    end
    
    if asURL        
        content = cellfun(@(x) constructURL(x,zipFile), content,'UniformOutput', false);
    end
    
    if nargout == 1
        varargout{1} = content;
    elseif nargout == 2
        varargout{1} = content;
        varargout{2} = entries;
    end

end

function noEntries = positionAtCentralDirectoryRecord( fid )

SHORT = uint8(2);
WORD = uint8(4);
DWORD = uint8(8);
ZIP64_MAGIC_SHORT = uint32(65535);
ZIP64_EOCDL_LENGTH = uint32(WORD + WORD + DWORD + WORD );
minDistanceFromEnd = uint32(WORD + SHORT + SHORT + SHORT + SHORT + WORD + WORD + SHORT);
maxDistanceFromEnd = minDistanceFromEnd + ZIP64_MAGIC_SHORT;

    noEntries = [];
    % Set pointer to eof to get file length
    fseek(fid,0,'eof');    
    fileLength = ftell(fid);
    
    if fileLength < minDistanceFromEnd
        ME = MException('getZipContents:NotAZip','Archive is not a ZIP archive');
        throwAsCaller(ME);
    end
    
    % Set pointer to the farthest loction from eof that an eocd with comments
    % can exist
    startSearchPosition = fileLength - maxDistanceFromEnd;    
    fseek(fid,startSearchPosition,'bof');
    % Find EOCD signature match 
    [status, position] = isSig( fread(fid,[1,(maxDistanceFromEnd-minDistanceFromEnd+5)],'*uint8'), 'EOCD');
%     k = strfind(fread(fid,[1,(maxDistanceFromEnd-minDistanceFromEnd+5)],'*uint8'),getSig('EOCD'));
    % If signatuyre is found, position pointer there, else error
    if status %~isempty(k)        
        eocd = startSearchPosition + position - 1; % File is zero based   
        fseek(fid,eocd,'bof');
    else
        ME = MException('getZipContents:NotAZip','Archive is not a ZIP archive');
        throwAsCaller(ME);
    end
    % Move pointer and search for ZIP64EOCD signature
    fseek(fid,eocd-ZIP64_EOCDL_LENGTH,'bof');
    k = strfind(fread(fid,[1,ZIP64_EOCDL_LENGTH],'*uint8'),getSig('ZIP64EOCD'));
    
    if isempty(k) %#ok<STREMP>
        % Read end of central directory and set pointer to first central
        % directory record
        %
        % Reset to pointer back to EOCD
        fseek(fid,eocd,'bof');
        bytes = fread(fid,[1,22],'*uint8');
        offset = typecast(bytes(17:20),'uint32');
        noEntries = typecast(bytes(9:10),'uint16');
        % Set pointer to start of centeral directory
        fseek(fid,offset,'bof');
    else
        % Read Zip64 end of central directory and set pointer to Zip64 end
        % of central directory record
        %
        % Reset pointer
        bytes = fseek(fid,ftell(fid)+ZIP64_EOCDL_LENGTH,'bof');
        offset = typecast(bytes(9:16),'uint64');
        % Set pointer to start of Zip64 end of centeral directory record
        fseek(fid,offset,'bof');    
        
    end
    
end

function entries = populateFromCenteralDirectory( fid, noEntries )

    entries(noEntries) = io.Entry();%createEntry();
    
    doLoop = true;

    k = 1;
    
    while doLoop
        
        [ doLoop, bytes ] = io.Util.readChunk( fid, 'cfh' );
        
        if doLoop
            
            entries(k) = io.Entry(fid,bytes);
            
            k = k + 1;
        end
       
    end
end

function entries = populateFromZip64CenteralDirectory( fid )

end

function URL = constructURL( URL, fileName )

    if startsWith(URL,'/')
        URL = URL(2:end);
    end
    if endsWith(fileName,'.jar')
        URL = ['jar:file:/',strrep(fileName,'\','/'),'!/',URL];
    else
        URL = ['file:/',strrep(fileStr,'\','/')];
        URL = strrep(URL,' ','%20');        
    end
    
end

function [status, out] = readChunk( fid, chunkType )

    status = false;
    out = [];

    switch chunkType
        case {'cfh','central directory header'}
            bytes = fread(fid,[1,46],'*uint8');
            
            status = isSig(bytes(1:4),'cfh') ;
            
            if status
                out = createEntry( fid, bytes );              
            else                
                curPos = ftell(fid);
                fseek(fid,curPos-46,'bof');
            end
            
        case {'lfh','local file header'}
            
        otherwise
            
    end

end

function entry = createEntry( fid, bytes )
    
    entry = struct(...
        'VersionMadeBy',[],...
        'VersionNeededToExtract',[],...
        'GeneralPurposeBit',[],...
        'CompressionMethod',[],...                
        'LastModFileTime',[],...
        'LastModFileDate',[],...
        'CRC32',[],...
        'CompressedSize',[],...
        'UncompressedSize',[],...
        'NameLength',[],...
        'ExtraFieldLength',[],...
        'FileCommentLength',[],...
        'DiskNumberStart',[],...
        'InternalFileAttributes',[],...
        'ExternalFileAttributes',[],...
        'Offset',[],...
        'FileName',[],...
        'ExtraField',[],...
        'FileComment',[]);
 
    if nargin
        entry.VersionMadeBy = typecast(bytes(5:6),'uint16');
        entry.VersionNeededToExtract = typecast(bytes(7:8),'uint16');
        entry.GeneralPurposeBit = io.GeneralPurposeBit(typecast(bytes(9:10),'uint16'));%readGeneralPurposeBits(typecast(bytes(9:10),'uint16'));%org.apache.commons.compress.archivers.zip.GeneralPurposeBit.parse(int8(bytes),8);
        entry.CompressionMethod = typecast(bytes(11:12),'uint16');
        entry.LastModFileTime = typecast(bytes(13:14),'uint16');
        entry.LastModFileDate = typecast(bytes(15:16),'uint16');
        entry.CRC32 = typecast(bytes(17:20),'uint32');
        entry.CompressedSize = typecast(bytes(21:24),'uint32');
        entry.UncompressedSize = typecast(bytes(25:28),'uint32');
        entry.NameLength = typecast(bytes(29:30),'uint16');
        entry.ExtraFieldLength = typecast(bytes(31:32),'uint16');
        entry.FileCommentLength = typecast(bytes(33:34),'uint16');
        entry.DiskNumberStart = typecast(bytes(35:36),'uint16');
        entry.InternalFileAttributes = typecast(bytes(37:38),'uint16');
        entry.ExternalFileAttributes = typecast(bytes(39:42),'uint32');
        entry.Offset = typecast(bytes(43:46),'uint32');
        entry.FileName = fread(fid,[1,entry.NameLength],'*char');
        if entry.ExtraFieldLength ~= 0
            entry.ExtraField = fread(fid,[1,entry.ExtraFieldLength],'*uint8');
        else
            entry.ExtraField = [];
        end
         if entry.FileCommentLength ~= 0
            entry.FileComment = fread(fid,[1,entry.FileCommentLength],'*char');
        else
            entry.FileComment = '';
        end
    end
    
    function platform = getPlatform( byte )
        
        switch byte
            case 0  ;platform = 'FAT/VFAT/FAT32';
            case 1  ;platform = 'Amiga';
            case 2  ;platform = 'OpenVMS';                
            case 3  ;platform = 'UNIX';
            case 4  ;platform = 'VM/CMS';                 
            case 5  ;platform = 'Atari ST';
            case 6  ;platform = 'OS/2 H.P.F.S.';                 
            case 7  ;platform = 'Macintosh';
            case 8  ;platform = 'Z-System';                 
            case 9  ;platform = 'CP/M';
            case 10 ;platform = 'Windows NTFS';                 
            case 11 ;platform = 'MVS (OS/390 - Z/OS)';
            case 12 ;platform = 'VSE';                 
            case 13 ;platform = 'Acorn Risc';
            case 14 ;platform = 'VFAT';                 
            case 15 ;platform = 'alternate MVS';
            case 16 ;platform = 'BeOS';                 
            case 17 ;platform = 'Tandem';
            case 18 ;platform = 'OS/400';                 
            case 19 ;platform = 'OS X (Darwin)';
            otherwise ;platform = 'undefined';
        end
        
    end

    function version = getVersion( byte )
        val = double(byte);
        mver = val/10;
        minver = mod(val,10);
        version = sprintf('%2.4f/%2.4f',mver,minver);
        
    end

    function s = readGeneralPurposeBits( value )
        
        s.useEncyrption = logical(bitget(value,1,'uint16'));
        s.useDataDescriptor = logical(bitget(value,3,'uint16'));
        s.useStrongEncyrption = logical(bitget(value,6,'uint16'));
        s.useUTF8ForNames = logical(bitget(value,12,'uint16'));
        s.isLocalHeaderMasked = logical(bitget(value,14,'uint16'));
        if logical(bitget(value,2,'uint16'))
            s.slidingDictionarySize = 8192;
        else
            s.slidingDictionarySize = 4096;
        end
         if logical(bitget(value,3,'uint16'))
            s.numberOfShannonFanoTrees = 3;
        else
            s.numberOfShannonFanoTreee = 2;
        end       
    end

    function [time, date] = convertDosDateTime( timeCode, dateCode )
        bits = dec2bin(timeCode,16);
        seconds = bin2dec(bits(1:5))*2;
        minutes = bin2dec(bits(6:11));
        hour = bin2dec(bits(12:16));
        
        bits = dec2bin(dateCode,16);
        day = bin2dec(bits(1:5));
        month = bin2dec(bits(6:9));
        year = bin2dec(bits(10:16)) + 1980;
        
        date = char(datetime(year,month,day,'Format','dd/MM/yyy'));
        time = char(datetime(year,month,day,hour,minutes,seconds,'Format','HH:mm:ss'));
    end
    
    % jDate = org.apache.commons.compress.archivers.zip.ZipUtil.dosToJavaTime(typecast(bytes(13:16),'int32'));
end

function sig = getSig( strId )

    switch lower(strId)
        
        case 'eocd' % End of central directory signature
            sig = uint8([80,75,5,6]);
        case 'zip64eocd' % zip64 end of central directory locator signature
            sig = uint8([80,75,6,7]);
        case 'zip64eocdr' % zip64 end of centeral directory record signature
            sig = uint8([80,75,6,6]);
        case 'digitalsig'
            sig = uint8([80,75,5,5]);
        case 'cfh' % Central file header signature
            sig = uint8([80,75,1,2]);
        case 'aedr' % Archive extra data signature  
            sig = uint8([80,75,6,8]);
        case 'lfh' % Local file header signature 
            sig = uint8([80,75,3,4]);
        otherwise
            sig = uint8([255,255,255,255]);
    end
end

function [status, position] = isSig( bytes, strId )
    
    position = [];
    noBytes = numel(bytes);
    if noBytes == 4
        status = isequal(bytes,getSig(strId));
    elseif noBytes > 4
        position = strfind(bytes,getSig(strId));
        status = ~isempty(position);        
    end
end

function bytes = hex2bytes( hexStr )
% hex2bytes returns a row vector of uint8 bytes from a hex string
    bytes = uint8(org.apache.commons.compress.archivers.zip.ZipLong.getBytes(hex2dec(hexStr))');
end
