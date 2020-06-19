classdef Zip64ExtendedInformationExtraField <  io.Fields.Field

    methods
        function this = Zip64ExtendedInformationExtraField( id, dataBytes  )
            this = this@io.Fields.Field(id,dataBytes);
            this.Name_ = 'Zip64ExtendedInformationExtraField';
        end
        
        function [msg,compressedSize,uncompressedSize,offset,diskNumber] =...
                update(this,compressedSize,uncompressedSize,offset,diskNumber)
            
            msg = [];
            neededFlags = [compressedSize,uncompressedSize,offset,0] < 0;
            
            if any(neededFlags)
                requiredSize = ( neededFlags * io.Util.Z64_EXT_SIZE) + 4;
                fieldSize = numel(this.RawData_);
                if fieldSize > requiredSize
                    msg = 'The Zip64 extended infomation field is not large enough to contain all required information';
                    return;
                end  
                newVals = zeros([1,4],'uint64');
                noBytesPerField = neededFlags .* io.Util.Z64_EXT_SIZE';
                ptr = 1;
                for itr = 1:4
                    if neededFlags(itr)
                        noBytes = noBytesPerField(itr);
                        if noBytes == 8
                            clazz = 'uint64';
                        else
                            clazz = 'uint32';
                        end
                        newVals(itr) = typecast(this.RawData_(ptr:ptr+noBytes-1),clazz);
                        ptr = ptr + noBytes + 1;
                    end
                end
                    
                if isequal(compressedSize,-1)
                    compressedSize = newVals(1);
                else
                    compressedSize = uint64(compressedSize);
                end

                if isequal(uncompressedSize,-1)
                    uncompressedSize = newVals(2);
                else
                    uncompressedSize = uint64(uncompressedSize);
                end

                if isequal(offset,-1)
                    offset = newVals(3);
                else
                    offset = uint64(offset);
                end  
            else
                compressedSize = uint64(compressedSize);
                uncompressedSize = uint64(uncompressedSize);
                offset = uint64(offset);
            end
            
            diskNumber = uint32(diskNumber);
        end
    end
end

