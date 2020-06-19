classdef Entry < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Dependent = true)
        
        MadeByZipVersion
        MadeByPlatform
        ExtractMinVersion
        ExtractMinFeature;
        CanBeExtracted
        IsEncrypted
        IsStronglyEncrypted
        UsesUTF8
        CompressionMethod
        FileTimeStamp
        CompressedSize
        UncompressedSize
        IsDirectory
        IsTextFile
        Path
        FileName

    end
    
    properties(Access = protected)

        VersionMadeBy_(1,1) uint16;
        VersionNeededToExtract_(1,1) uint16;
        GeneralPurposeBit_@io.GeneralPurposeBit
        CompressionMethod_(1,1) uint16;               
        LastModFileTime_(1,1) uint16;
        LastModFileDate_(1,1) uint16;
        CRC32_(1,1) int32;
        CompressedSize_(1,1) uint64;
        UncompressedSize_(1,1) uint64;
        DiskNumberStart_(1,1) uint32;
        InternalFileAttributes_(1,1) uint16;
        ExternalFileAttributes_(1,1) int32;
        Offset_(1,1) uint64;
        RawFileName_(1,:) uint8
        ExtraField_
        FileComment_ 

    end
    
    properties(Access = private, Constant = true )

    end
    
    methods
        function this = Entry( fid, readLocalHeader ) %, bytes )
            
            if nargin
                if nargin == 1
                    readLocalHeader = false;
                end
                
                this.loadFromFile(fid,readLocalHeader);
                    
            end

        end

    end
    
    methods(Access = protected)
        
        function loadFromFile( this, fid, readLocalHeader )
           
            try
                [B16,B32,GPB,rawFileName,extraFields,commentField] = read( fid );
            catch ME
                throwAsCaller(ME)
            end
            
            this.VersionMadeBy_             = B16(1);
            this.VersionNeededToExtract_    = B16(2);
            this.CompressionMethod_         = B16(3);
            this.LastModFileTime_           = B16(4);
            this.LastModFileDate_           = B16(5);
            this.DiskNumberStart_           = B16(9);
            this.InternalFileAttributes_    = B16(10);            

            this.CRC32_                     = B32(1);
            this.ExternalFileAttributes_    = B32(4);
            
            neededFlags = [B32(2),B32(3),B32(5),0] < 0;
            
            %fields = org.apache.commons.compress.archivers.zip.ExtraFieldUtils.parse(extraFields',false);
            
            if any(neededFlags)
                if isempty(extraFields)
                     ME = MException('Entry:BadZip64Extra',...
                        'The Zip 64 extended information extra field is required, but not present'); 
                    throwAsCaller(ME);                   
                end
                z64ExtraFieldMask = ismember([extraFields(:).Id],1);                          
                if sum(z64ExtraFieldMask) == 0
                    ME = MException('Entry:BadZip64Extra',...
                        'The Zip 64 extended information extra field is required, but not present'); 
                    throwAsCaller(ME);                
                end
                z64ExtraField = extraFields(z64ExtraFieldMask);
                [msg,this.CompressedSize_,...
                     this.UncompressedSize_,...
                     this.Offset_,...
                     this.DiskNumberStart_] = z64ExtraField.update(B32(2),B32(3),B32(5),B16(8));
                if ~isempty(msg)
                    ME = MException('Entry:BadZip64Extra',msg); 
                    throwAsCaller(ME); 
                end
            else
                this.CompressedSize_ = uint64(B32(2));
                this.UncompressedSize_ = uint64(B32(3));
                this.Offset_ = uint64(B32(5));
                this.DiskNumberStart_ = uint32(B16(8));
            end

            this.GeneralPurposeBit_ = GPB;
            
            this.RawFileName_ = rawFileName;
            
            if ~isempty(extraFields)
                this.ExtraField_ = extraFields;
            end
            
            this.FileComment_ = commentField;
            
            if readLocalHeader
            
                endOfCD = ftell(fid);

                fseek(fid,this.Offset_,'bof');

                status = io.Util.isa(fread(fid,[1,4],'*uint8'),'lfh');
                
                if status
                    
                end
                

                fseek(fid,endOfCD,'bof');

            end
   
        end
    end
   
    methods
       
        function fullFileName = getFullFileName( this )
            if this.GeneralPurposeBit_.useUTF8ForNames
                fullFileName = native2unicode(char(this.RawFileName_),'UTF-8');
            else
                fullFileName = char(this.RawFileName_);
            end
        end
        
        function fileName = getFileName( this )
            if this.GeneralPurposeBit_.useUTF8ForNames
                fileName = native2unicode(char(this.RawFileName_),'UTF-8');
            else
                fileName = char(this.RawFileName_);
            end            
            if ~io.Util.isDirectory(fileName)
                fileName = io.Util.getFileNameFromURL(fileName);
            end           
        end
        
        function path = getPath( this )
            if this.GeneralPurposeBit_.useUTF8ForNames
                path = native2unicode(char(this.RawFileName_),'UTF-8');
            else
                path = char(this.RawFileName_);
            end            
            if ~io.Util.isDirectory(path)
                [~,path] = io.Util.getFileNameFromURL(path);
            end           
        end        
        
%         function time = getTime( this )
%             time = io.Util.dosTimeToJavaTime([this.LastModFileTime,]);
%         end
        
        function gpb = getGPB( this )
           gpb = this.GeneralPurposeBit_; 
        end
        
        function code = getCompressionMethodCode( this )            
            code = this.CompressionMethod_;
        end
        
        function code = getPlatformCode( this )
            code = this.VersionMadeBy_(2);
        end
        
        function mode = getFileMode( this )
            
            switch this.getPlatformCode
                case 0
                    mode = this.ExternalFileAttributes_;
                case 3 
                    mode = bitand(bitshift(this.ExternalFileAttributes_,-16,'uint32'),l);
                otherwise
                    mode = 0;
            end
            
        end
        
        function data = getRawExtraData( this )
            data = this.ExtraField_;
        end
        
        function comments = getFileComments( this )
            if isempty(this.FileComment_)
                comments = '';
            else
                comments = this.FileComment_;
            end
        end
        
    end
    
    methods
       
        function value = get.MadeByZipVersion( this )
            bytes = typecast(this.VersionMadeBy_,'uint8');
            value = io.Util.getVersion(bytes(1));
        end
        
        function value = get.MadeByPlatform( this )
            bytes = typecast(this.VersionMadeBy_,'uint8');
            value = io.Util.getPlatform(bytes(2));
        end   
        
        function value = get.ExtractMinVersion( this )
            bytes = typecast(this.VersionNeededToExtract_,'uint8');
            value = io.Util.getVersion(bytes(1));
        end   
        
        function value = get.ExtractMinFeature( this )
            bytes = typecast(this.VersionNeededToExtract_,'uint8');        
            value = io.Util.getMinimumFeature(bytes(2));
        end      
            
        function value = get.IsEncrypted( this )
            value = this.GeneralPurposeBit_.useEncyrption;
        end
        
        function value = get.IsStronglyEncrypted( this )
            value = this.GeneralPurposeBit_.useStrongEncyrption;
        end        

        function value = get.UsesUTF8( this )
            value = this.GeneralPurposeBit_.useUTF8ForNames;
        end 
        
        function value = get.CompressionMethod( this )
            value = io.Util.getCompressionMethod(this.CompressionMethod_);
        end 

        function value = get.CompressedSize( this )
            value = this.CompressedSize_;
        end

        function value = get.UncompressedSize( this )
            value = this.UncompressedSize_;
        end
        
        function fileName = get.FileName( this )
            fileName = this.getFileName();            
        end  
        
        function path = get.Path( this )
            path = this.getPath();            
        end 
        
        function value = get.IsDirectory( this )
            value = io.Util.isDirectory(this.getFullFileName);
        end         
        
        function boolean = get.IsTextFile( this )
           boolean = logical(bitget(this.InternalFileAttributes_,1,'uint16')); 
        end
        
        function boolean = get.CanBeExtracted( this )
            supportedModes = io.Util.getSupportedModes();
            canByMode = ismember(this.CompressionMethod_,supportedModes);
            
            boolean = canByMode && this.GeneralPurposeBit_.isExtractable();
            
        end        

    end
end

function [B16,B32,GPB,rawFileName,extraFields,commentField] = read( fid )

    B16 = zeros([10,1],'int16');
    B32 = zeros([5,1],'int32');

    B16(1:2) = fread(fid,2,'*int16');
    GPB = io.GeneralPurposeBit(fread(fid,[1,16],'ubit1=>uint8'));
    B16(3:5) = fread(fid,3,'*int16');
    B32(1:3) = fread(fid,3,'*int32');
    B16(6:10) = fread(fid,5,'*int16');
    B32(4:5) = fread(fid,2,'*int32');               

    rawFileName = fread(fid,[1,B16(6)],'*uint8');
    
    if B16(7) > 0
        extraFields = io.Util.parseExtraData(fread(fid,[1,B16(7)],'*uint8'));
    else
        extraFields = [];
    end

    if B16(8) ~= 0
        commentField = fread(fid,[1,B16(8)],'*char');
    else
        commentField = '';
    end 

end

