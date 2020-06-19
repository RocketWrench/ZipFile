classdef ZipFile <  handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties( Dependent = true)
        
        ArchiveFileName
        
        Files
        
        Directories
    end
    
    properties(Access = protected)
       
        ArchiveFile_ = '';
        
        Files_ = {};
        
        Directories_ = {};
        
        FilesIndexMap = [];
        
        Entries@io.Entry
        
        JavaZipFile = [];
        
        StreamCopier = [];
        
        resetJavaZipFile = true;
        
        Zip64ExtensibleData_ = [];
        
        RawDigitalSignature_ = [];
        
        SupportedModes_ = [];
        
        ArchiveComments_ = [];

    end

    properties(Access = protected, Constant = true)
       
        Version = '1.0.0';
    end    
    
    methods
        function this = ZipFile( file )
           
            if nargin
                try
                    this.load(file);
                catch ME
                    throw(ME);
                end
            end
                
        end
        
        function delete( this )
            
           try this.JavaZipFile.close; catch; end 
        end

    end
    
    methods
        
        function set.ArchiveFileName( this, file )
            if strcmp(file,this.ArchiveFile_); return; end
            this.resetJavaZipFile = true;
            this.load(file);
        end
        
        function file = get.ArchiveFileName( this )
            file = this.ArchiveFile_;
        end
        
        function content = get.Files( this )
            content = this.Files_;%keys(this.FileNameToEntryMap)';
        end
        
        function directories = get.Directories( this )
            directories = this.Directories_;%keys(this.FileNameToEntryMap)';
        end  

    end
    
    methods(Access = public)
        
        function this = extract( this, whichEntries, outputFolder )
        % extract Extracts the entries defined by the argrument 
        % 'which' to the folder 'outputFolder' or pwd.
        
            narginchk(1,3);
            % Use pwd for output directory unless a output directory is
            % provided, if outputFolder argrument is empty, open folder dialog
            if nargin == 3
                if isempty(outputFolder)
                    outputFolder = uigetdir(pwd,'Select output folder');
                    
                    if isequal(outputFolder,0)
                        return
                    end
                end
                
                if ~exist(outputFolder,'dir')
                    mkdir(outputFolder)
                end                
            else
                
                outputFolder = pwd;
                if nargin == 1
                    whichEntries = [];
                end
            end

            entries = this.getEntry(whichEntries);
            
            for itr = 1:numel(entries)

                entry = entries(itr);

                [inputStream,msg] = this.getInputStreamForImpl( entry );

                if isempty(inputStream)
                    error('ZipFile:BadInputStream',msg);
                end                    

                outputFileName = fullfile(outputFolder,entry.FileName);

                jOutFile = java.io.File(outputFileName);

                outputStream = java.io.FileOutputStream(jOutFile);

                this.copyStream(inputStream, outputStream);
            end
            
        end
        
        function dataReader = getDataReaderFor( this, whichEntry )
            
            entry = this.getEntry(whichEntry,false);
            entry = entry(1);

            dataReader = this.getReader( entry, 'data' );           
        end
                
        function lineReader = getLineReaderFor( this, whichEntry )
 
            entry = this.getEntry(whichEntry,false);
            entry = entry(1);
            
            lineReader = this.getReader( entry, 'line' );
        end

        function inputStream = getInputStreamFor( this, whichEntry )
            
            entry = this.getEntry(whichEntry);
            entry = entry(1);
            
            inputStream = this.getInputStreamForImpl(entry);
        end
        
        function URL = getURLFor( this, whichEntry )
            
            entries = this.getEntry(whichEntry,false);
            
            fullFileNames = arrayfun(@(x) x.getFullFileName, entries, 'UniformOutput',false)';
            
            URL = cellfun(@(x) io.Util.constructURL(x,this.ArchiveFile_),fullFileNames,'UniformOutput',false);
            
            if numel(URL) == 1
                URL = URL{1};
            end
            
        end
        
        function icons = getAllImagesAsIcons( this )
            
            icons = [];
            
            files = this.Files;
            validExtensions = io.Util.getImageIOFileExtensions();
            
            idxs = find(contains(files,validExtensions));
            
            if ~isempty(idxs)
                entries = this.Entries(this.FilesIndexMap(idxs));
                URLs = this.getURLFor(entries);
                noURLs = numel(URLs);
                icons = javaArray('javax.swing.ImageIcon',noURLs);
               
                for itr = 1:noURLs
                    icons(itr) = javax.swing.ImageIcon(URLs{itr});
                end
            end
            
        end
        
        function digSig = getDigitalSignature( this )
            digSig = this.RawDigitalSignature_;
        end
        
        function modes = getSupportedModes( this )
            modes = this.SupportedModes_;
        end
        
        function comments = getComments( this )
            if isempty(this.ArchiveComments_)
                comments = '';
            else
                comments = this.ArchiveComments_;
            end
        end
        
        entries = getEntry( this, which, allowDirectories ) 
    end

    methods( Access = protected )
        
        function load( this, file )

            try
                [this.Entries,...
                 this.Zip64ExtensibleData_,...
                 this.RawDigitalSignature_,...
                 this.ArchiveFile_,...
                 this.ArchiveComments_] = this.getZipFileContent(file);

            catch ME
                throwAsCaller(ME);
            end
            
            notDirectoryMask = ~[this.Entries(:).IsDirectory];
            
            this.Files_ = {this.Entries(notDirectoryMask).FileName}';
            
            this.Directories_ = arrayfun(@(x) x.getFullFileName,this.Entries((~notDirectoryMask)),'UniformOutput',false)';
            
            this.FilesIndexMap = find(notDirectoryMask)';  
            
            this.SupportedModes_ = io.Util.getSupportedModes;
        end

        function copyStream( this, inputStream, outputStream )
           
            if isempty(this.StreamCopier)
                this.StreamCopier = com.mathworks.mlwidgets.io.InterruptibleStreamCopier.getInterruptibleStreamCopier;
            end
            
            try
                this.StreamCopier.copyStream(inputStream,outputStream);
                outputStream.close
            catch ME
                
            end

        end
        
        function [ inputStream , msg ] = getInputStreamForImpl( this, entry )
            
            msg = true;
                       
            if isempty(this.JavaZipFile) || this.resetJavaZipFile
                try
                    this.JavaZipFile =...
                        org.apache.commons.compress.archivers.zip.ZipFile(java.io.File(this.ArchiveFile_),[]);
                catch ME
                    io.Util.handleIOExceptions(ME);
                end
            end
            
            this.resetJavaZipFile = false;
            
            jEntry = this.JavaZipFile.getEntry(entry.getFullFileName);

            if isempty(jEntry)
                inputStream = [];
                msg = sprintf('Could not find a corresponding ZipArchive entry for %s',entry.FileName);
            elseif ~this.JavaZipFile.canReadEntryData(jEntry)
                inputStream = [];
                msg = sprintf('Found unsupported compression method for %s.\nTry updating org.apache.commons.compress to the latest version',entry.FileName);
            else
                try
                    inputStream = this.JavaZipFile.getInputStream(jEntry);
                catch ME
                    io.Util.handleIOExceptions(ME);
                end
            end           
        end
        
        function reader = getReader( this, entry, whichReader )

            [inputStream,msg] = this.getInputStreamForImpl(entry);
            
            if ~isempty(inputStream)
                switch whichReader
                    case 'data'
                        reader = io.DataReader( entry, inputStream);
                    case 'line'
                        reader = io.LineReader( entry, inputStream);
                end                        
            else
                ME = MException('ZipFile:BadInputStream',msg);
                throwAsCaller(ME);
            end           
        end
    end
    
    methods( Access = protected, Static = true )
        
        function [entries, extraData, digitalSignature, zipFile,comments] = getZipFileContent( zipFile )

            % Open the file for reading
            [fid,msg] = fopen(zipFile,'r');            

            if fid < 3
               ME = MException('getZipContents:badFile','Cannot read the file %s\n%s',zipFile,msg);
               throwAsCaller(ME);
            end
            zipFile = fopen(fid);
            cleanUp = onCleanup(@()fclose(fid));
            % Check first 4 bytes of file for a 'lfh' signature. 
            if ~io.Util.isa( fread(fid,[1,4],'*uint8'), 'lfh' )
               ME = MException('getZipContents:badLFH',...
                   'The file, %s,\ndoes not start with a local file header signature\nIt may be a self-exctracting archive file\nor an empty zip file',zipFile); 
               throwAsCaller(ME);
            end

            [noEntries,extraData,comments] = io.ZipFile.positionAtCentralDirectoryRecord( fid );

            if ~isempty(noEntries)
                [entries,digitalSignature] = io.ZipFile.populateFromCentralDirectory( fid, noEntries );
            else
                % TODO: Better explaination
               ME = MException('getZipContents:NoEntries',...
                   'No entries found'); 
               throwAsCaller(ME);            
            end
        end 
        
        function [entries,digitalSignature] = populateFromCentralDirectory( fid, noEntries )
        % populateFromCentralDirectory - Parses central directory records
        % and retuen an array of io.Entry objects
        
            %Pre-allocation
            entries(noEntries) = io.Entry();
            digitalSignature = [];
            
            CFH = uint8([80,75,1,2]);
        
            doLoop = true;

            k = 1;

            while doLoop
                % Verify and returns a byte array of the fixed fields
%                 [ doLoop, bytes ] = io.Util.readChunk( fid, 'cfh' );
                doLoop = isequal(fread(fid,[1,4],'*uint8'),CFH);

                if doLoop
                % The constructor of the io.Entry objects parses fixed
                % fields and reads any variable length fields so that the file
                % pointer should be at the beginning of the next record
                    entries(k) = io.Entry( fid );%, bytes );

                    k = k + 1;
                else
                % We assume doLoop is false because all the central directory
                % entries have been read and then attempt to read the digital 
                % signature block, if present.  
                
                    [ status, bytes ] = io.Util.readChunk( fid, 'digital' );
                    
                    if status
                        digitalSigSz = typecast(bytes(5,6),'uint16');
                        digitalSignature = fread(fid,[1,digitalSigSz],'*uint8');                        
                    end
                end

            end
        end         
        
        function [noEntries, extraData, comments] = positionAtCentralDirectoryRecord( fid )
        % positionAtCentralDirectoryRecord - Attempts to position the file
        % pointer at the first central directory record by locating and then 
        % parsing the end of central directory record or Zip64 end of 
        % central directory locator.
        %
        % inspired by:  
        % org.apache.commons.compress.archivers.zip.ZipFile
        %
        % Reference:
        % https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
            
            extraData = [];
            comments = [];

            % Set pointer to eof to get file length
            fseek(fid,0,'eof');    
            fileLength = ftell(fid);
            % Zip files cannot be smaller than the length of the end of centeral
            % directory record (22 btes )
            if fileLength < io.Util.MIN_LENGTH
                ME = MException('getZipContents:NotAZip','Archive is not a ZIP archive, file length is less than 22 bytes');
                throwAsCaller(ME);
            end
            % Start search at EOCD length(22 bytes) from eof
            eocdPos = -double(io.Util.EOCD_CHUNK_SIZE(2));
            fseek(fid,eocdPos,'eof');
            % Check for EOCD signature
            foundEOCDSig = io.Util.isa(fread(fid,[1,4],'*uint8'),'eocd');
            % Search while EOCD signature is not found and we have not searched
            % farther than the maximum (supposedly) length of the EOCD
            % block
            % ZIP_MAGIC_NUMBER = 65535 bytes.
            % See reference 4.4.12
            % TODO: Maybe faster just to read in MAGIC NUMBER of bytes and
            % search for EOCD signature in that byte array, wuld depend on
            % length of comment field
            maxSearchLength = -min(fileLength,io.Util.MAX_LENGTH);
            while (~foundEOCDSig) && (eocdPos > maxSearchLength)
                eocdPos = eocdPos - 1;
                fseek(fid,eocdPos,'eof');
                foundEOCDSig = io.Util.isa( fread(fid,[1,4],'*uint8'), 'EOCD');               
            end
            % Error if EOCD still not found
            if ~foundEOCDSig        
                ME = MException('getZipContents:NotAZip','Archive is not a ZIP archive or is corrupt.\nEnd of centeral directory signature could not be found');
                throwAsCaller(ME);
            end
            % Reset to pointer back to start of EOCD and then read EOCD as
            % block
            fseek(fid,eocdPos,'eof');
            [~,bytes] = io.Util.readChunk( fid, 'eocd'); 
            offset = typecast(bytes(17:20),'uint32');
            noEntries = typecast(bytes(9:10),'uint16'); 
            commentLen = typecast(bytes(21:22),'uint16');
            if commentLen > 0
                comments = fread(fid,[1,commentLen],'*char');
            end
            % Move pointer towards bof to search for ZIP64EOCD locator
            % signature.
            % This assumes that the EOCD is preceded by the Zip64EOCDL
            % chunk as does apache.commons.compress.zip.ZipFile and is
            % hinted at in the reference
            fseek(fid,eocdPos-double(io.Util.Z64EOCDL_CHUNK_SIZE(2)),'eof');
            % Get ZIP64EOCD locator chunk
            [foundZ64EOCDLSig,Z64EOCDLBytes] = io.Util.readChunk(fid,'z64eocdl');
            % If  Zip64 EOCDL is foune (ver 1/2 (?) format)
            if foundZ64EOCDLSig
                % Read Zip64 end of central directory locator and set 
                % pointer to Zip64 end central directory record, than parse
                % the record
                %
                offsetToZ64EOCDR = typecast(Z64EOCDLBytes(9:16),'uint64');
                % Set pointer to start of Zip64 end of centeral directory record
                fseek(fid,offsetToZ64EOCDR,'bof'); 
                % Parse Zip64 end of central directory locator, find offset
                % to central directory record
                [offset,noEntries,extraData] = io.ZipFile.readZip64EndOfCentralDirectoryRecord( fid );
            end
            % Set pointer to start of central directory
            fseek(fid,offset,'bof'); 
        end  
        
        function [offsetToCD,noEntriesOnThisDisk,extensibleData] =...
                readZip64EndOfCentralDirectoryRecord( fid )
        % readZip64EndOfCentralDirectoryRecord - Parse Zip64 end of central
        % directory record for 8 byte offset to centeral directory and 
        % number of entries, return extnesible data if present
        
            [status,bytes ] = io.Util.readChunk( fid, 'z64eocdr' );
            
            if status
                
                sizeOf = typecast(bytes(5:12),'uint64');
                % verMadeBy = typecast(bytes(12:14),'uint16');
                % verToExtract = typecast(bytes(15:16),'uint16');
                % noOfDisks = typecast(bytes(17:20),'uint32');
                % noDiskWSCD = typecast(bytes(21:24),'uint32');
                noEntriesOnThisDisk = typecast(bytes(25:32),'uint64');
                % noEntriesTotal = typecast(bytes(33:40),'uint64');
                % szCD = typecast(bytes(41:48),'uint64');
                offsetToCD = typecast(bytes(49:56),'uint64');
                
                sizeOfExtensibleData = sizeOf - (uint64(io.Util.Z64EOCDR_CHUNK_SIZE(2)) + uint64(12));
                
                extensibleData = [];
                
                if sizeOfExtensibleData > 0
                    extensibleData = fread(fid,[1,sizeOfExtensibleData],'*uint8');
                end
                
                
            else
                % TODO: See if we can recover from this error
                ME = MException('readZip64EndOfCentralDirectoryRecord:BadSignature',...
                    'Could not find the Zip64 end of central directory record'); 
                throwAsCaller(ME);                 
            end         
            
        end  
        
    end
end

