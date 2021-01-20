function listing = zipdir( zipFileName )

    narginchk(0,1);
    nargoutchk(0,1);
    
    listing = ceateListItem();
    
    if (nargin == 0)
        
        filter = {'*.zip;*.jar;*.docx','Archive Files(*.zip.*.jar,*.docx)'};
        [file,path] = uigetfile(filter,'Select archive file');
        
        if isequal(file,0)
            return
        end 
        
        zipFileName = fullfile(path,file);
    end

    [fid,errmsg] = fopen(zipFileName);
    
    if fid < 3
        error('listArchiveEntries:badFile',...
            'Unable to open %s , fopen returns %s',zipFileName,errmsg)        
    end
    
    fileName = fopen(fid);
    
    fclose(fid);
    
    zipFile = org.apache.commons.compress.archivers.zip.ZipFile(java.io.File(fileName),[]);
    
    cleanUp = onCleanup(@()zipFile.close);
    
    entries = zipFile.getEntries;

    while entries.hasMoreElements
        listing(end+1,1) = ceateListItem(entries.nextElement); %#ok<AGROW>
    end
    
    listing(1) = [];

    function item = ceateListItem( entry )

        item = struct(...
            'name','',...
            'folder','',...
            'date','',...
            'uncompressedsize',0,...
            'isdir',false,...
            'canbeextracted',true,...
            'datenum',0);

        if (nargin == 0)
            return
        else
            
            entryName =  char(entry.getName);
            
            pos = find(entryName == '/',1,'last') + 1;

            item.name = entryName(pos:end);
            item.folder = entryName(1:pos-1);   
            item.date = char(entry.getLastModifiedDate.toString);            
            item.uncompressedsize = double(entry.getSize());
            item.isdir = entry.isDirectory();
            item.canbeextracted = zipFile.canReadEntryData(entry);
            item.datenum = datenum([1970,1,1,0,0,double(entry.getLastModifiedDate.getTime)/1000]);
        end
    end
end
