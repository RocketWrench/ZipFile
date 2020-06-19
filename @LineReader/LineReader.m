classdef LineReader < handle
    %UNTITLED3 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        FileName
        
        Entry
        
        LineNumber
    end
    
    properties( Access = protected )
        
        LineNumberReader
        
        InputStreamReader
        
        Entry_@io.Entry;
        
        InputStream
        
        hasFirstLineBeenRead = false;
        
        FileSize

    end
    
    methods
        function this = LineReader( entry, inputStream )

            this.Entry_ = entry;
            
            uncompressedSize = entry.UncompressedSize;
            this.FileSize = uncompressedSize;
            
            buffSize = 4096;
            if uncompressedSize < buffSize
                buffSize = uncompressedSize;
            end
            
            this.InputStreamReader = java.io.InputStreamReader(inputStream);
            
            this.LineNumberReader = java.io.LineNumberReader(this.InputStreamReader,buffSize);
        end
        
        function delete( this )
           
            try this.InputStreamReader.close(); catch; end
            try this.LineNumberReader.close(); catch; end
        end

    end
    
    methods
       
        function fileName = get.FileName( this )
           fileName = this.Entry_.FileName; 
        end
        
        function entry = get.Entry( this )
            entry = this.Entry_; 
        end 
        
         function lineNumber = get.LineNumber( this )
            try
                lineNumber = this.LineNumberReader.getLineNumber() + 1;
            catch
                lineNumber = -1;
            end
        end        
    end    
    
    methods
       
        function line = readLine( this )
            try
                
                line = char(this.LineNumberReader.readLine());
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end
        
        function mark( this )
 
        end
    end
end

