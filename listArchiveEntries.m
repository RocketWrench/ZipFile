function list = listArchiveEntries( archiveFile )


    zipFile = org.apache.commons.compress.archivers.zip.ZipFile(java.io.File(archiveFile),[]);
    cleanUp = onCleanup(@()zipFile.close);
    entries = zipFile.getEntries;
    [~,f,e] = fileparts(archiveFile);
    fprintf('Contents of %s%s\n',f,e);
    while entries.hasMoreElements
        try
            fprintf([char(entries.nextElement.getName),'\n']);
        catch
            continue
        end
    end
end

