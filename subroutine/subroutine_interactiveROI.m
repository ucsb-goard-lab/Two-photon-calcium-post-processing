function filename = subroutine_interactiveROI(filename)

%% subroutine_interactiveROI.m
% 
% Interactive ROI selector - see B_DefineROI for usage instructions.
% 
% Called by B_DefineROI
%
% Code written by Michael Goard & Gerald Pho - updated: Oct 2013

%% ROI type ('circular' or 'polygonal')
ROItype='circular';
parameter_default = {'-0.03','50','30','200','0.01'};

%% load file
if nargin < 1
    disp('Load activity map file')
    [filename,pathname]=uigetfile('.mat','Load activity map file');
    cd(pathname);
end
currVar.filename = filename;
load(filename,'data');

%% load data channels
currVar.green = subroutine_normalize(data.avg_projection); % average projection of green channel
currVar.amap = subroutine_normalize(data.activity_map); % activity map of green channel
blankFrame = zeros(size(currVar.green));
currVar.masks = blankFrame;

%% initialize variables
currVar.stopFlag = 0;
currVar.cellMasks={};
currVar.currCell=1;
currVar.tempMasks = blankFrame;
currVar.currROI = [];
savemode = 0;

%% setup GUI
close all
currVar.fig=figure;
set(currVar.fig,'Position',[300 100 950 950]);
set(currVar.fig,'Color',[1 1 1])
l = 30; % leftmost
s = 30; % spacing
currVar.greenOn = uicontrol(currVar.fig,'Value',1,'Style','togglebutton',...
    'Units','characters','Position',[l 6 20 2],'String','Avg Projection',...
    'Callback',@replotImage);
currVar.amapOn = uicontrol(currVar.fig,'Value',1,'Style','togglebutton',...
    'Units','characters','Position',[l+s 6 20 2],'String','Activity Map',...
    'Callback',@replotImage);
currVar.masksOn = uicontrol(currVar.fig,'Value',1,'Style','togglebutton',...
    'Units','characters','Position',[l+2*s 6 20 2],'String','Masks',...
    'Callback',@replotImage);

currVar.greenColor = uicontrol(currVar.fig,'Style','popupmenu',...
    'String',{'Grey','Red','Green','Blue'},'Value',1,'Units','characters',...
    'Position',[l 5 20 1],'Callback',@replotImage);
currVar.amapColor = uicontrol(currVar.fig,'Style','popupmenu',...
    'String',{'Grey','Red','Green','Blue'},'Value',2,'Units','characters',...
    'Position',[l+s 5 20 1],'Callback',@replotImage);
currVar.masksColor = uicontrol(currVar.fig,'Style','popupmenu',...
    'String',{'Grey','Red','Green','Blue'},'Value',4,'Units','characters',...
    'Position',[l+2*s 5 20 1],'Callback',@replotImage);

currVar.greenGain = uicontrol(currVar.fig,'Style','slider','Max',1.5,'SliderStep',[0.1 0.3]/1.5,...
    'Value',0.4,'Units','characters','Position',[l 3 20 1],'Callback',@replotImage);
currVar.amapGain = uicontrol(currVar.fig,'Style','slider','Max',1.5,'SliderStep',[0.1 0.3]/1.5,...
    'Value',1,'Units','characters','Position',[l+s 3 20 1],'Callback',@replotImage);
currVar.masksGain = uicontrol(currVar.fig,'Style','slider','Max',1.5,'SliderStep',[0.1 0.3]/1.5,...
    'Value',1,'Units','characters','Position',[l+2*s 3 20 1],'Callback',@replotImage);

currVar.greenLabel = uicontrol(currVar.fig,'Style','text',...
    'String','0.4','Units','characters','Position',[l 2 20 1]);
currVar.amapLabel = uicontrol(currVar.fig,'Style','text',...
    'String','0.4','Units','characters','Position',[l+s 2 20 1]);
currVar.masksLabel = uicontrol(currVar.fig,'Style','text',...
    'String','0.4','Units','characters','Position',[l+2*s 2 20 1]);

currVar.greenAuto = uicontrol(currVar.fig,'Style','checkbox','Tag','green',...
    'String','Auto Detect','Units','characters','Position',[l 1 20 1],'Callback',@autoDetect);
currVar.amapAuto = uicontrol(currVar.fig,'Style','checkbox','Tag','amap',...
    'String','Auto Detect','Units','characters','Position',[l+s 1 20 1],'Callback',@autoDetect);

currVar.finished = uicontrol(currVar.fig,'Style','pushbutton','Units','characters',...
    'Position',[l+4*s-5 4 20 2],'String','Finished','Callback',@stopLoop);

currVar.modeSelect = uicontrol(currVar.fig,'Style','listbox','Units','characters',...
    'Position',[l+3*s 2.5 15 5.5],'String', 'Ellipse|Freehand|Zoom|Pan','Callback',@changeMode);

set(gcf,'DeleteFcn',@stopLoop)
set(gcf,'WindowButtonDownFcn',@updateMask)
set(gcf,'KeyPressFcn',@changeMode)


%% display image
replotImage

%% loop

while currVar.stopFlag == 0
    pause (0.5)
    
    if ~isempty(get(0,'CurrentFigure')) && get(currVar.modeSelect,'Value') < 3 && (isempty(currVar.currROI) || ~isvalid(currVar.currROI))
        changeMode
    end
    
end

filename = currVar.filename;

%% Subfunctions %%
    function changeMode(src,evt)
        if nargin==2 && ~isempty(evt)
            switch evt.Character
                case 'e'
                    set(currVar.modeSelect,'Value',1);
                case 'f'
                    set(currVar.modeSelect,'Value',2);
                case 'z'
                    set(currVar.modeSelect,'Value',3);
                case 'p'
                    set(currVar.modeSelect,'Value',4);
                otherwise
                    return
            end
        end
        replotImage
        
        switch get(currVar.modeSelect,'Value')
            case 1
                zoom off;
                pan off;
                set(gcf,'WindowButtonDownFcn',@updateMask)
                currVar.currROI = imellipse;
            case 2
                zoom off;
                pan off;
                set(gcf,'WindowButtonDownFcn',@updateMask)
                currVar.currROI = imfreehand;
            case 3
                zoom on;
                h = zoom;
                set(h,'ActionPostCallback',@replotImage)
            case 4
                pan on;
                h = pan;
                set(h,'ActionPostCallback',@replotImage)
        end
    end

    function stopLoop(src,evt)
        if currVar.stopFlag == 0
            if src~= currVar.finished % do not save if figure was closed
                currVar.currCell = 1;
                currVar.tempMasks(:) = 0;
                currVar.stopFlag=1;
                if savemode == 1 || savemode ==2
                    currVar.filename = [currVar.filename(1:end-9) '_data'];
                else
                    disp('Figure closed -- masks not saved.')
                    currVar.filename = [];
                end
                return
            end
            if max(currVar.tempMasks(:))>0
                keep = questdlg('Keep autodetected cells?','Keep autodetected cells?','Yes','No','Cancel','Yes');
                
                switch keep
                    case 'Yes'
                        newMasks = bwboundaries(currVar.tempMasks,4,'noholes')';
                        for j = 1:length(newMasks)
                            newMasks{j}(:,[1,2]) = newMasks{j}(:,[2,1]); % switch to [X,Y], instead of [r,c]
                        end
                        currVar.cellMasks = [currVar.cellMasks, newMasks];
                        currVar.currCell = length(currVar.cellMasks)+1;
                        currVar.masks = currVar.masks+currVar.tempMasks;
                        currVar.tempMasks(:,:) = 0;
                        set(currVar.([currVar.autoBox 'Auto']),'Enable','off');
                        replotImage
                    case 'No'
                        currVar.tempMasks(:,:) = 0;
                        set(currVar.([currVar.autoBox 'Auto']),'Value',0);
                        replotImage
                end
                
            else
                commandwindow
                fprintf('Found %d cells.\n', currVar.currCell-1);
                
                % dilate poly masks before saving
                [m,n]=size(data.avg_projection);
                for j = 1:length(currVar.cellMasks)
                    position=currVar.cellMasks{j};
                    tempmask=imdilate(poly2mask(position(:,1),position(:,2),m,n),ones(3));
                    newmask = bwboundaries(tempmask,4,'noholes');
                    if ~isempty(newmask)
                        currVar.cellMasks{j} = newmask{1}(:,[2,1]);
                    else
                        currVar.cellMasks{j} = NaN;
                    end
                end
                removemasks = cellfun(@(x) max(isnan(x(:))),currVar.cellMasks);
                currVar.cellMasks(removemasks)=[];
                                
                % append or overwrite?
                if currVar.currCell-1 == 0
                    savemode = 0;
                    
                elseif isfield(data,'cellMasks')
                    if ~iscell(data.cellMasks)
                        % convert BW masks to poly and dilate
                        oldCellMasks = cell(1,max(data.cellMasks(:)));
                        for j = 1:max(data.cellMasks(:))
                            tempmask = imdilate(data.cellMasks==j,ones(3));
                            newmask = bwboundaries(tempmask,4,'noholes');
                            if ~isempty(newmask)
                                oldCellMasks{j} = newmask{1}([2,1]);
                            else
                                oldCellMasks{j} = [0,0];
                            end
                        end
                        data.cellMasks = oldCellMasks;
                    end
                    
                    fprintf('File already has %d cell masks.\n',length(data.cellMasks));
                    
                    savemode = input('Append (2), Overwrite (1), or Cancel (0)? ');
                else
                    savemode = input('Save (1), or Cancel (0)? ');
                end
                if savemode == 2
                    data.cellMasks = [data.cellMasks,currVar.cellMasks];
                    eval(['save ' currVar.filename(1:end-9) '_data data']);
                    disp('File saved')
                elseif savemode == 1
                    data.cellMasks=currVar.cellMasks; % save poly masks
                    eval(['save ' currVar.filename(1:end-9) '_data data']);
                    disp('File saved')
                else
                    disp('File not saved')
                    currVar.filename = [];
                end
                
                
                replotImage
                pause(1)
                close
                currVar.stopFlag=1;
            end
        end
    end

    function replotImage(src,evt)        
        % update labels
        currAxis = axis;  
        set(currVar.greenLabel,'String',sprintf('%1.1f',get(currVar.greenGain,'Value')));
        set(currVar.amapLabel,'String',sprintf('%1.1f',get(currVar.amapGain,'Value')));
        set(currVar.masksLabel,'String',sprintf('%1.1f',get(currVar.masksGain,'Value')));
        
        green = get(currVar.greenOn,'Value')*chooseColor(currVar.green,get(currVar.greenColor,'Value'));
        amap = get(currVar.amapOn,'Value')*chooseColor(currVar.amap,get(currVar.amapColor,'Value'));
        masks = get(currVar.masksOn,'Value')*chooseColor(currVar.masks+currVar.tempMasks,get(currVar.masksColor,'Value'));
        
        currVar.curr_image= get(currVar.greenGain,'Value')*green + get(currVar.amapGain,'Value')*amap ...
            + get(currVar.masksGain,'Value')*masks;
        currVar.curr_image(currVar.curr_image>1) = 1;
        image(currVar.curr_image)
        axis square
        if min(currAxis == [0 1 0 1]) == 0
            axis(currAxis)
        end
        if max(currVar.tempMasks(:))>0
            title('Press "Finished" to confirm/reject autodetected cells.')
        else
            title(sprintf('cells found: %d',currVar.currCell-1))
        end
        xticks = [ceil(min(xlim)) round(mean(xlim)) floor(max(xlim))];
        yticks = [ceil(min(ylim)) round(mean(ylim)) floor(max(ylim))];
        set(gca,'XTick',xticks)
        set(gca,'YTick',yticks)        
        set(gca,'XTickLabel',sprintf('%d|Zoom = %1.2fx|%d',xticks(1),...
            size(currVar.curr_image,2)/diff(xlim),xticks(3)))
        set(gca,'YTickLabel',sprintf('%d|Zoom = %1.2fx|%d',yticks(1),...
            size(currVar.curr_image,1)/diff(ylim),yticks(3)))
    end

    function im = chooseColor(frame, color)
        blank = zeros(size(frame));
        switch color
            case {1,'grey','gray','k'}
                im = cat(3,frame,frame,frame);
            case {2,'red','r'}
                im = cat(3,frame,blank,blank);
            case {3,'green','g'}
                im = cat(3,blank,frame,blank);
            case {4,'blue','b'}
                im = cat(3,blank,blank,frame);
            otherwise
                im = cat(3,blank,blank,blank);
        end
    end

    function autoDetect(src,evt)
        autoBox = get(src,'Tag');
        if max(currVar.tempMasks(:))>0
            currvalue = get(currVar.([autoBox 'Auto']),'Value');
            set(currVar.([autoBox 'Auto']),'Value',~currvalue);
            
        elseif get(currVar.([autoBox 'Auto']),'Value') == 1
            currVar.autoBox = autoBox;
            prompt = {'Threshold offset:','Threshold window','Min pixels','Max Pixels','H_maxima'};
            if isfield(currVar,'answer') && length(currVar.answer) == 5
                def = currVar.answer;
            else
                def = parameter_default;
            end
            currVar.answer = inputdlg(prompt,'Parameters',1,def);
            params = cellfun(@str2double,currVar.answer);
            if ~isempty(params)
                [currVar.tempMasks newMasks] = subroutine_autodetect(currVar.(currVar.autoBox),params);

            else
                set(currVar.([currVar.autoBox 'Auto']),'Value',0);
            end
            
        end
        replotImage
    end

    function updateMask(src,evt)
        if strcmp(get(src,'SelectionType'),'open') % require double click
            if ~isempty(currVar.currROI) && isvalid(currVar.currROI)
                if get(currVar.modeSelect,'Value') == 2 % freehand
                    position = getPosition(currVar.currROI);
                else
                    position = getVertices(currVar.currROI); % ellipse
                end
                if ~isempty(position)
                    [m,n]=size(data.avg_projection);
                    mask_disp=poly2mask(position(:,1),position(:,2),m,n);
                    
                    % check for complete encompassing of mask
                    in = [];
                    for j = 1:length(currVar.cellMasks)
                        if min(mask_disp(poly2mask(currVar.cellMasks{j}(:,1),...
                                currVar.cellMasks{j}(:,2),m,n)))==1
                            in = [in, j];
                        end
                    end
                    if isempty(in)
                        % update cell mask matrix
                        currVar.cellMasks{currVar.currCell}=position;
                        currVar.currCell=currVar.currCell+1;
                        
                        % update display image
                        currVar.masks=currVar.masks+mask_disp;
                    else
                        % delete cell masks
                        for j = 1:length(in)
                            removemask = poly2mask(currVar.cellMasks{in(j)}(:,1),currVar.cellMasks{in(j)}(:,2),m,n);
                            removemask = imdilate(removemask,ones(3));
                            currVar.masks(removemask) = 0;
                        end
                        
                        currVar.cellMasks(in) = [];
                        currVar.currCell = currVar.currCell-length(in);
                    end
                    replotImage
                end
            end
        end
    end

end 