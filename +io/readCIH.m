function [params, cih] = readCIH( path )
% READCIH: Reads and parses Photron header files (cih and cihx)
%
% usage: [p,cih] = readCIH('mycihfile.cihx') % Parses the cihx or cih file
% usage: [p,cih] = readCIH()                 % Opens a file selection
%                                              dialog
%
% Inputs :
%
%    path - (OPTIONAL) path to a cih or cihx file.  The associated mraw
%            file must be in the same directory.
%
% Ouputs :
%
%    params -  Structure of parameters needed to read a mraw file in matlab
% 
%                 Width: Image width
%                Height: Image height
%               IsColor: Flag indicating if image is mono or color
%              ColorBit: Numer of color bits
%     EffectiveBitDepth: Effective bit depth
%         MachineFormat: Machine format, as would be expected by fread
%                Frames: Number of frames
%          TriggerFrame: Trigger frame index
%             SkipFrame: Number greater than 1 indicates that frames were
%                        skipped when recorded
%             FrameRate: Frame rate in frames per second
%       ImageDimensions: Image dimensions [width,height] or [width,height,3]
%         BytesPerPixel: Number of bytes per pixel
%         BytesPerImage: Total number of bytes per image (as stored)
%       PrecisionString: Precision string as expected by fread
%        ReadDimensions: Dimension of data as expected by fread
%          BitsPerPixel: Bits per pixel
%              ReadType: Code indicating how the pixels are stored
%                        on disk, possible values are,'PACKED_10BIT',
%                        'PACKED_12BIT','RAW_WORD','RAW_BYTE' or nan when
%                        unknown
%           CanBitShift: Flag indicating if the pixel values can be bit
%                        shifted
%              BitShift: Amount of bit shift
%              Pointers: Array of uint64 pointers to the images in the mraw
%                        file, [noframes,1]
%              DataFile: Full path to the associated mraw file
%              getFrame: A function handle which returns an image frame by
%                        frame number
%
%   cih - The data from the camera information header in a structure. The
%       fields and values of cih depend upon the version of the cih/cihx
%       file and any processing steps taken.
%
% Notes on the getFrame function handle:
%
% usage: frame = params.getframe(params,index,doBitShift) 
%        % Returns the frame at index, and optionaly bit shifts the image
% usage: frame = params.getframe(params,index) % Returns the frame at index
%
%        The getFrame function is fairly performant by itself but does
%        require a call to fopen per frame.
%
% Notes : cihx header files are parsed in java DOM.
%
% Author : Collin Pecora
% Version : 1.0
% Release data : 4/30/21
    
    narginchk(0,1)
    
    cih = struct();
    params = struct();    
    
    if isequal(nargin,0)
        filter = {...
            '*.cih;*.cihx;*.mraw','Photron Files (*.cih,*.cihx,*.mraw)';
            '*.cihx'             ,'CIHX Files (*.cihx)';
            '*.cih'              ,'CIH Files (*.cih)';
            '*.mraw'             ,'MRAW Files (*.mraw)'};
        [file,path,idx] = uigetfile(filter,'Select Photron file',... 
            'MultiSelect','off', pwd);
        if ~isequal(file,0)
            path = fullfile(path,file);
        else
            return
        end
    else
        if endswidth(path,'cihx')
            idx = 2;
        elseif endswidth(path,'cih')
            idx = 3;
        elseif endswidth(path,'mraw')
            idx = 4;
        else
            idx = 0;
        end
        
    end
       
    [status,cihFilePath,mrawFilePath,fid,msg,isxml] = checkFiles(path,idx);
    
    if all(status)        
        if isxml
            cih = parseCIHX(cihFilePath);
        else
            cih = parseCIH(cihFilePath);
        end

        params = constructParameters(cih,isxml,fid,mrawFilePath);
    else
        if isempty(msg)
            if ~any(status) % Found none
                error('readCIH:FilesDoNotExist',...
                    'One or both of\n%s\n%s\nis unreadable or unavailble',...
                    cihFilePath,mrawFilePath) 
            end
            
            if ~status(1)
                error('readCIH:BadCIH',...
                    'The data file (mraw) and the corresponding header file (cih,cihx)\nmust be in the same folder\nIn the folder\n%s\nOnly\n%s\nCould be found',...
                    path,mrawFilePath)
            end            
            
            if ~status(2)
                error('readCIH:BadMRAW',...
                    'The data file (mraw) and the corresponding header file (cih,cihx)\nmust be in the same folder\nIn the folder\n%s\nOnly\n%s\nCould be found',...
                    path,cihFilePath)
            end
        else
            error('cihReader:NoAccess','Unable to access %s\nfopen returned %s',f,msg)
        end        
    end

end

function [status,cihFilePath,mrawFilePath,fid,msg,isxml] = checkFiles( path, idx )
% CHECKFILES - validate mraw file

    status = false(1,2);
    isxml = false;
    [p,f,e] = fileparts(path);
    mrawFilePath = checkMRAW();
    
    switch idx
        case 1 % Any            
            switch e
                case '.cihx'
                    cihFilePath = checkCIHX();                    
                case '.cih'
                    cihFilePath = checkCIH(); 
                case '.mraw'
                    cihFilePath = checkForEither();
            end       
        case 2 % cihx
            cihFilePath = checkCIHX();
        case 3 % cih
            cihFilePath = checkCIH();            
        case 4 % mraw
            cihFilePath = checkForEither();
    end
    
    status(1) = isequal(exist(cihFilePath ,'file'),2);
    
    function mrawFilePath = checkMRAW()
    
        mrawFilePath = fullfile(p,[f,'.mraw']);
        
        [fid,msg] = fopen(mrawFilePath,'r');
    
        status(2) = isequal(exist(mrawFilePath,'file'),2) & (fid > 2);
    end

    function cihFilePath = checkCIHX()
        isxml = true;
        cihFilePath = fullfile(p,[f,'.cihx']);        
    end

    function cihFilePath = checkCIH()
        isxml = false;
        cihFilePath = fullfile(p,[f,'.cih']);        
    end

    function cihFilePath = checkForEither()
        cihFilePath = '';
        cihPath = fullfile(p,[f,'.cih']); 
        cihxPath = fullfile(p,[f,'.cihx']);
        
        which = [isequal(exist(cihPath ,'file'),2),isequal(exist(cihxPath ,'file'),2)];
        
        if any(which)
            if which(1)
                isxml = false;
                cihFilePath = cihPath;
            else
                isxml = true;
                cihFilePath = cihxPath;
            end
            
        end
    end
end

function cih = parseCIHX( filename )

    cih = struct();

    document = getDocument(filename);

    [uniqueNodes,nonUniqueNodes] = walkTree(document);

    % Process  unique nodes
    for itr = 1:length(uniqueNodes)

        subs = strSplit(uniqueNodes{itr,1});
        setField(uniqueNodes{itr,2});
    end        

    % Process non-unique nodes
    subscell = cellfun(@(x) strSplit(x),nonUniqueNodes(:,1),'UniformOutput',false);
    lensubs = cellfun(@numel,subscell);

    check = true(length(nonUniqueNodes),1);

    k = 1;        
    while any(check)
        % Find candidates that are at the same level and have the same
        % root
        nlevels = lensubs(k); % Number of levels of the current node           
        mask = (lensubs == nlevels) &...
            (contains(nonUniqueNodes(:,1),subscell{k}(1))) & check; 
        % Convert candidate subscell from a cell array of cells to a
        % cell array of strings
        candidates = reshape([subscell{mask}],nlevels,sum(mask))';
        % candidate to nonUniqueNodes index management
        midxs = find(mask);            
        % Matching score by level
        score = ismember(candidates,subscell{k});
        % If the current node and its candidate matches are the same at
        % all levels then they have the same fieldname and only differ
        % in their value
        hasOneField = all(all(score));            
        if hasOneField

            idxs = midxs(mask);

            fieldName = subscell{k}{end};
            subs = subscell{k}(1:end-1);
            values = nonUniqueNodes(idxs,end);
            nvalues = numel(values);

            s = struct();
            for itr = 1:nvalues
                s(itr,1).(fieldName) = values{itr};
            end                
        else

            idxs = midxs(score(:,nlevels-1));

            fieldName = candidates{1,nlevels-1};

            subFieldNames = unique(candidates(score(:,nlevels-1),end),'stable');

            nsubfields = numel(subFieldNames);

            subs = candidates(1,1:nlevels-2);

            values = nonUniqueNodes(idxs,end);

            nvalues = numel(values);

            nelements = nvalues/nsubfields;

            range = 1:nvalues;
            range = reshape(range,[nsubfields,nelements]);

            s = struct();
            for itr = 1:nelements
                idx = range(:,itr);
                for itn = 1:nsubfields
                    value = values{idx(itn)};
                    s(itr,1).(fieldName).(subFieldNames{itn}) = value;
                end
            end
        end

        setField(s);         

        check(idxs) = false;

        k = find(check,1,'first');
    end
    
    function setField( value )
        
        types = repmat({'.'},size(subs));
        cih = builtin('subsasgn',cih,...
                struct('type',types,'subs',subs),value); 
    end      
end

function cih = parseCIH( filename )

    fid = fopen(filename,'r');
    
    cih = struct();
    
    doLoop = true;

    while doLoop
        tline = fgetl(fid);
        doLoop = ~strcmpi(strtrim(tline),'end') && ischar(tline);
        if doLoop
            if isempty(tline); continue; end
            if strcmp(tline(1),'#')
                subheader = strtrim(tline(2:end));
                if strcmp(subheader(end),':')
                    subheader = subheader(1:end-1);
                end
                subheader = matlab.lang.makeValidName(subheader,'ReplacementStyle','delete');
            else
                [fieldName,value] = strtok(tline, ':');
                fieldName = matlab.lang.makeValidName(strtrim(fieldName),'ReplacementStyle','delete');
                cih.(subheader).(fieldName) = process(value(2:end));
            end
        end
       
    end
    
    fclose(fid);

    function value = process( value)
        value = strtrim(value);
        switch fieldName
            case 'Date'
                value = datetime(value,'InputFormat','yyyy/M/dd');
            case {'EdgeEnhance','ColorEnhance','ScaleMethod'}
                value = uint8(str2double(value));
            case {'CameraID','CameraNumber','HeadNumber','MaxHeadNumber','PartitionNumber',...
                   'DigitsOfFileNumber','AnalogBoardChannelNum'}
                value = uint32(str2double(value));
            case {'RecordRatefps','ImageWidth','ImageHeight','TotalFrame',...
                 'StartFrame','ColorBit','EffectiveBitDepth','TriggerTime',...
                 'CorrectTriggerFrame','SaveStep','Output8bitBitShift',...
                 'ShutterType2nsec','ColorBalanceR','ColorBalanceG','ColorBalanceB',...
                 'ColorBalanceBase','ColorBalanceMax','OriginalTotalFrame','PreLUTBrightness',...
                 'PreLUTContrast','PreLUTGain','PreLUTGamma','ScaleGridSpace',...
                 'ScalePixelSize','ScaleUnit','ScaleMagnification','ScaleRuler',...
                 'ScaleDistance','Scale2PointsDistance'}
                value = str2double(value);
            case 'ShutterSpeeds'
                value = eval(value);
            case 'TriggerMode'
                C = strsplit(value);
                tm.Mode = C{1};
                try frames = str2double(C{2});catch; frames = [];end
                tm.Frames = frames;
                value = tm;
            case {'ColorMatrixR','ColorMatrixG','ColorMatrixB'}
                value = str2double(strsplit(value,':'));
            otherwise
                
        end
               
    end
        
end

function params = constructParameters( cih, isXML, fid, datafilepath )
    
    if isXML
        width = cih.imageDataInfo.resolution.width;
        height = cih.imageDataInfo.resolution.height;
        isColor = strcmpi(cih.imageDataInfo.colorInfo.type,'color');
        colorBit = cih.imageDataInfo.colorInfo.bit;
        ebd = cih.imageDataInfo.effectiveBit.depth;
        isLower = strcmpi(cih.imageDataInfo.effectiveBit.side,'lower');
        nFrames = cih.frameInfo.totalFrame;
        triggerFrame = abs(cih.frameInfo.startFrame) + 1;
        skipFrame = cih.frameInfo.skipFrame;
        frameRate = cih.recordInfo.recordRate;
    else
        width = cih.CameraInformationHeader.ImageWidth;
        height = cih.CameraInformationHeader.ImageHeight;
        isColor = strcmpi(cih.CameraInformationHeader.ColorType,'color');
        colorBit = cih.CameraInformationHeader.ColorBit;
        ebd = cih.CameraInformationHeader.EffectiveBitDepth;
        isLower = strcmpi(cih.CameraInformationHeader.EffectiveBitSide,'lower');
        nFrames = cih.CameraInformationHeader.TotalFrame;
        triggerFrame = abs(cih.CameraInformationHeader.StartFrame) + 1;
        skipFrame = nan;
        frameRate = cih.CameraInformationHeader.RecordRatefps;        
    end
    
    if isLower
        mf = 'l';
    else
        mf = 'b';
    end    

    if isColor            
        imageDimensions = [width,height,3];
    else
        imageDimensions = [width,height];
    end

    baseNumberPixelsPerFrame = width * height;

    is8bit = false;

    switch colorBit
        case 10
            bytesPerPixel = ebd/8;
            bytesPerImage = baseNumberPixelsPerFrame * bytesPerPixel;
            precisionString = 'uint8=>uint16';
            readDimensions = [5,bytesPerImage/5];
            bitsPerPixel = ebd;
            readType = 'PACKED_10BIT';
        case 12
            bytesPerPixel = 2;
            bytesPerImage = baseNumberPixelsPerFrame * ebd/8;
            precisionString = 'uint8=>uint16';
            readDimensions = [3,bytesPerImage/3];
            bitsPerPixel = ebd;
            readType = 'PACKED_12BIT';               
        case 16
            bytesPerPixel = 2;
            bytesPerImage = baseNumberPixelsPerFrame * 2;
            precisionString = ['ubit',num2str(colorBit),'=>uint16']; 
            readDimensions = [1,bytesPerImage];
            if isLower
                bitsPerPixel = ebd;
            else
                bitsPerPixel = 16;
            end
            readType = 'RAW_WORD';               
        case 24
            is8bit = true;
            bytesPerPixel = 1;
            bytesPerImage = baseNumberPixelsPerFrame * 3;
            precisionString = '*uint8';
            readDimensions = [1,bytesPerImage];
            bitsPerPixel = 24;
            readType = 'RAW_BYTE';                 
        case 30
            bytesPerPixel = nan;
            bytesPerImage = nan;
            precisionString = ['ubit',num2str(colorBit/3),'=>uint16'];
            readDimensions = nan;
            bitsPerPixel = ebd * 3;
            readType = 'PACKED_10BIT';                
        case 36
            bytesPerPixel = nan;
            bytesPerImage = nan;
            precisionString = ['ubit',num2str(colorBit/3),'=>uint16'];
            readDimensions = nan;
            bitsPerPixel = ebd * 3;
            readType = 'PACKED_12BIT';                
        case 48
            bytesPerPixel = 2;
            bytesPerImage = baseNumberPixelsPerFrame * 6;
            precisionString = ['ubit',num2str(colorBit/3),'=>uint16']; 
            readDimensions = [1,bytesPerImage];
            if isLower
                bitsPerPixel = ebd * 3;
            else
                bitsPerPixel = 48;
            end
            readType = 'RAW_WORD';                 
        otherwise
            bytesPerPixel = 1;
            bytesPerImage = baseNumberPixelsPerFrame;
            precisionString = '*uint8';
            readDimensions = [1,bytesPerImage];
            bitsPerPixel = 8;
            readType = 'RAW_BYTE';                
    end

    canBitShift = ~is8bit;

    bitShift = nan;

    if canBitShift
       if isColor
            bitShift = 16 - (bitsPerPixel/3);
       else
            bitShift = 16 - bitsPerPixel;
       end
    end

    params.Width = width;
    params.Height = height;
    params.IsColor = isColor;
    params.ColorBit = colorBit;
    params.EffectiveBitDepth = ebd;
    params.MachineFormat = mf;
    params.Frames = nFrames;
    params.TriggerFrame = triggerFrame;
    params.SkipFrame = skipFrame;
    params.FrameRate = frameRate;
    params.ImageDimensions = imageDimensions;
    params.BytesPerPixel = bytesPerPixel;
    params.BytesPerImage = bytesPerImage;
    params.PrecisionString = precisionString;
    params.ReadDimensions = readDimensions;
    params.BitsPerPixel = bitsPerPixel;
    params.ReadType = readType;
    params.CanBitShift = canBitShift;
    params.BitShift = bitShift;
    params.Pointers = uint64((0:nFrames-1)' * baseNumberPixelsPerFrame * colorBit/8);
    params.DataFile = datafilepath;
    params.FileID = fid;
    params.getFrame = @(params,index,varargin) getFrame(params,index,varargin);
end

function frame = getFrame( params, index, varargin )

    narginchk(2,3);
    
    if (index < 1) || (index > params.Frames)
       ME = MException('readCIH:IndexOutOfBounds',...
            'Index out of bounds. Index must be between 1 and %d.',params.Frames);
        throwAsCaller(ME);
    end

    fid = fopen(params.DataFile,'rb');
    cleanUpObj = onCleanup(@()fclose(fid));

    pointer = params.Pointers(index);

    fseek(fid,pointer,'bof');

    doBitShift = ~isempty(varargin);

    if params.IsColor
        numPixs = params.BytesPerImage;
        pixels = fread(fid,numPixs,params.PrecisionString,0,params.MachineFormat);
        pixels = [pixels(1:3:end,1),pixels(2:3:end,1),pixels(3:3:end,1)];
    else
        switch params.ReadType
            case 'PACKED_10BIT'

            case 'PACKED_12BIT'
                buffer = fread(fid,params.ReadDimensions,params.PrecisionString,0,params.MachineFormat);

                pixels = [(bitshift(buffer(1,:),4) + bitshift(bitand(buffer(2,:),uint16(240)),-4));...
                          (bitshift(bitand(buffer(2,:),uint16(15)),8) + buffer(3,:))];

                pixels = pixels(:);
            case 'RAW_WORD'
                pixels = fread(fid,params.ReadDimensions,params.PrecisionString,0,params.MachineFormat);
            case 'RAW_BYTE'
                pixels = fread(fid,params.ReadDimensions,params.PrecisionString,0,params.MachineFormat);
            otherwise

        end
    end

    if doBitShift && params.CanBitShift
        pixels = bitshift(pixels,params.BitShift);
    end 
    
    frame = permute(reshape(pixels,params.ImageDimensions),[2,1,3]);

end

function document = getDocument( filename )

    fid = fopen(filename,'rb');

    bytes = fread(fid,'*uint8')';

    fclose(fid);

    startIdx = strfind(bytes,uint8('<cih>'));
    endIdx = strfind(bytes,uint8('</cih>')) + 6;

    parserFactory = javaMethod('newInstance',...
        'javax.xml.parsers.DocumentBuilderFactory'); 

    parser = javaMethod('newDocumentBuilder',parserFactory);        

    document = javaMethod('parse',parser,...
        org.xml.sax.InputSource(...
        java.io.ByteArrayInputStream(bytes(startIdx:endIdx))));
end

function c = strSplit( str )

    c = regexp(str, {filesep}, 'split');
    c = c{:};
end

function [uniqueNodes,nonUniqueNodes] = walkTree( document )
    
    tree = {};
    
    treeWalker = document.createTreeWalker(document.getDocumentElement,...
        org.w3c.dom.traversal.NodeFilter.SHOW_ELEMENT,[],false);
    
    node = treeWalker.nextNode;
    
    while ~isempty(node)
        
        if node.getLength == 1
            tree(end+1,1:2) = getNodeData( node ); %#ok<AGROW>
        end
        
        node = treeWalker.nextNode;
    end
    
    [~,~,ib] = unique(tree(:,1),'stable');
    notUniqueCnt = arrayfun(@(x) sum(x==ib),ib);
    uniqueMask = (notUniqueCnt == 1);

    uniqueNodes = tree(uniqueMask,:);
    nonUniqueNodes = tree(~uniqueMask,:);    
end

function data = getNodeData( node )

    strvalue = node.getTextContent.toCharArray';

    if ~contains(strvalue,{'/',':'})
        [value,status] = str2num(strvalue);
        if ~status
            value = strvalue;
        end
    else
        value = strvalue;
    end   

    name = '';
    
    % Put the node name in a file path like form by walking backwards
    % up the node hierarchy until either the document or the root node is
    % reached or the node is empty
    while ~isempty(node)
        if isequal(node.getNodeType,9) || isequal(node.getNodeIndex,1)
            break;
        end
        if isempty(name)
            fs = '';
        else
            fs = filesep;
        end
        name = [node.getNodeName.toCharArray',fs,name]; %#ok<AGROW>
        node = node.getParentNode;
    end

    data = {name,value};
end


