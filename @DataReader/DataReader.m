classdef DataReader < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties( Dependent = true )
        
        FileName
        
        Entry
    end
    
    properties( Access = protected )
        
        DataInputStream
        
        Entry_@io.Entry;

    end
    
    methods
        function this = DataReader( entry, inputStream )
            
            this.Entry_ = entry;
            
            this.DataInputStream = java.io.DataInputStream(inputStream);

        end
        
        function delete( this )
           
            try this.DataInputStream.close(); catch; end
        end

    end
    
    methods
       
        function fileName = get.FileName( this )
           fileName = this.Entry_.FileName; 
        end
        
        function entry = get.Entry( this )
            entry = this.Entry_; 
        end        
    end
    
    methods
        
        function boolean = readBoolean( this, n )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readBoolean' );
                end
                
                boolean = false([1,n]);
                
                for itr = 1:n
                    boolean(itr) = this.DataInputStream.readBoolean();
                end
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end
        
        function byte = readByte( this, n )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readBoolean' );
                end
                
                byte = zeros([1,n],'uint8');
                
                for itr = 1:n
                    byte(itr) = this.DataInputStream.readUnsignedByte();
                end
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end 
        
        function byte = readSignedByte( this, n )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readBoolean' );
                end
                
                byte = zeros([1,n],'int8');
                
                for itr = 1:n
                    byte(itr) = this.DataInputStream.readByte();
                end
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end        
        
        function character = readChar( this, n )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readChar' );
                end
                
                byte = zeros([1,n],'uint8');
                
                for itr = 1:n
                    byte(itr) = this.DataInputStream.readUnsignedByte();
                end
                
                character = char(byte);
            catch ME
                io.Util.handleIOExceptions( ME );    
            end
        end        
        
        function character = readUniCodeChar( this, n )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readUniCodeChar' );
                end
                
                byte = zeros([1,n],'uint16');
                
                for itr = 1:n
                    byte(itr) = this.DataInputStream.readChar();
                end
                
                character = char(byte);                
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end  
        
        function val = readDouble( this, n )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readDouble' );
                end
                
                val = zeros([1,n]);
                
                for itr = 1:n
                    val(itr) = this.DataInputStream.readDouble();
                end                
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end
        
        function val = readSingle( this )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readSingle' );
                end
                
                val = zeros([1,n],'single');
                
                for itr = 1:n
                    val(itr) = this.DataInputStream.readFloat();
                end 
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end
        
        function val = readUint16( this )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readUint16' );
                end
                
                val = zeros([1,n],'uint16');
                
                for itr = 1:n
                    val(itr) = this.DataInputStream.readUnsignedShort();
                end                 
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end
        
        function val = readInt16( this )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readUint16' );
                end
                
                val = zeros([1,n],'int16');
                
                for itr = 1:n
                    val(itr) = this.DataInputStream.readShort();
                end                 
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end        
        
        function val = readUint32( this )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readUint32' );
                end
                
                val = zeros([1,n],'uint32');
                
                for itr = 1:n
                    bytes = this.readByte(4);
                    val(itr) = typecast(bytes,'uint32');
                end                 
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end 
        
        function val = readInt32( this )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readUint32' );
                end
                
                val = zeros([1,n],'int32');
                
                for itr = 1:n
                    val(itr) = this.DataInputStream.readInt();
                end                 
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end        
        
        function val = readUint64( this )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readUint64' );
                end
                
                val = zeros([1,n],'uint64');
                
                for itr = 1:n
                    val(itr) = this.DataInputStream.readLong();
                end                
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end
        
        function val = readInt64( this )
            try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'readUint64' );
                end
                
                val = zeros([1,n],'int64');
                
                for itr = 1:n
                    bytes = this.readByte(8);
                    val(itr) = typecast(bytes,'int64');
                end                
            catch ME
                io.Util.handleIOExceptions( ME );
            end
        end        
        
        function skipBytes( this, n )
             try
                if nargin == 1
                    n = 1;
                else
                    n = io.Util.validateNumber( n, 'skipBytes' );
                end
                
                this.DataInputStream.skipBytes(n);
            catch ME
                io.handleIOExceptions( ME );
            end           
        end
        
        
    end
end

