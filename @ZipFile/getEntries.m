function entries = getEntry( this, which, allowDirectories )

            if isa(which,'io.Entry')
                entries = which;
                return
            end
            
            narginchk(1,3);
            
            if nargin < 3
                allowDirectories = true;
            end
            
            if nargin == 1
                entries = getAll();
                return
            end

            if isempty(which)
                entries = getAll();
            elseif ischar(which)  
                if strcmp(which,'all')
                    entries = getAll();
                else
                    start = regexp(this.Files_,which,'start');
                    mask = ~cellfun('isempty',start);
                    
                    if sum(mask) > 0
                        entries = this.Entries(this.FilesIndexMap(mask));
                    else
        
                       ME = MException('ZipFile:FindEntry','Cannot locate an archive entry using the regular expression, ''%s''',which);
                       throwAsCaller(ME);
                    end

                end
            elseif iscell(which)

            elseif isnumeric(which)
                if isvector(which)
                    
                    minIdx = min(which);
                    maxIdx = max(which);
                    
                    if (minIdx > 0) && (maxIdx <= numel(this.Files))
                        entries = this.Entries(this.FilesIndexMap(which));
                    else
                        if minIdx < 1
                            msg = 'One or more of the provided indices is less than 1';
                        elseif maxIdx > numel(this.Files)
                            msg = sprintf('One or more of the provided indices is greater than the number of files (%d)',numel(this.Files));
                        end
                       ME = MException('ZipFile:FindEntry',msg);
                       throwAsCaller(ME);
                    end                  
                else
                   ME = MException('ZipFile:FindEntry','Indices into the entry list must be a scalar or a vector');
                   throwAsCaller(ME);
                end
            end 
            
            if isempty(entries)
               ME = MException('ZipFile:FindEntry','Could not find an archive entry match');
               throwAsCaller(ME);
            end
            
            function entries = getAll()
                entries = this.Entries;
                if ~allowDirectories
                    notDirectoryMask = ~[this.Entries(:).IsDirectory];
                    entries = entries(notDirectoryMask);
                end                
            end
        end

