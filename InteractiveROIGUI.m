classdef InteractiveROIGUI < handle
    % Interactive ROI selector - see B_DefineROI for usage instructions.
    %
    % Called by B_DefineROI
    %
    % Code written by Michael Goard & Gerald Pho - updated: Oct 2013
    % Update 24Jan2022 KS to work with latest MATLABS using new GUI packages
    % (2018b+) and reorganized the code for easier development in the future
    
    % Update 27Jan2022 KS: Code overhaul, removed the while loop to improve
    % performance across the board.
    % Code flow:
    % Initial call builds the GUI and suppresses warnings then plots the
    % first image and enters the main function 'changeMode', which detects
    % the current mode and properly changes the GUI mode to suit (The GUI
    % spends the most time waiting in changeMode for things to happen).
    
    % Any actions then will cause an update which clears existing ROIs
    % (after taking their data), followed by a replot and change mode
    % again.
    
    % This repeats until the finish button is pressed.
    
    properties (Constant = true)
        L = 30; % leftmost
        S = 30; % spacing
    end
    
    properties
        default_parameters = {'-0.03', '50', '30', '200', '0.01'}; % for the autodetect
        filename
        data
        
        green
        amap
        masks
        
        cell_masks
        curr_cell
        autodetect_masks
        savemode
        curr_image
        
        gui
        
        autodetect_params
        autodetect_map % this is a temporary variable that changes depending on which one is clicked
        
        killed = false;
    end
    
    methods
        function obj = InteractiveROIGUI(filename)
            if nargin < 1 || isempty(filename)
                fprintf('Load activity map file\n');
                [filename, pathname] = uigetfile('.mat', 'Load activity map file:');
                cd(pathname);
            end
            obj.filename = filename;
            obj.data = importdata(obj.filename);
            obj.green = obj.normalize(obj.data.avg_projection);
            obj.amap = obj.normalize(obj.data.activity_map);
            obj.masks = zeros(size(obj.green));
            
            obj.initialize();
            
            obj.replot();
            obj.changeMode();
        end
        
        function initialize(obj)
            obj.cell_masks = {};
            obj.curr_cell = 1;
            obj.autodetect_masks = zeros(size(obj.green));
            obj.savemode = 0;
            obj.buildGUI();
            
            % suppress mode warnings (not great)
            warning('off', 'all');
        end
        
        function out = getFilename(obj)
            out = fileparts(obj.filename);
        end
        
        %% Helper functions %%
        function resumeAll(obj)
            uiresume(obj.gui.fig);
            uiresume(); % to catch any extras...
        end
        
        function update(obj) % Added a single update function to package everything 24Jan2022 KS
            obj.replot();
            obj.changeMode();
        end
        
        function out = getCurrentMode(obj)
            out = obj.gui.modeSelect.SelectedObject.String;
        end
        
        function clearROIs(obj) % clears existing ROIs 24Jan2022 KS
            h_roi = findobj(obj.gui.fig, 'Tag', 'ROI');
            if ~isempty(h_roi)
                h_roi.delete();
            end
        end
        
        function out = kill(obj)
            warning('on', 'all');
            obj.killed = true;
            out = obj.filename;
            delete(obj.gui.fig);
            return
        end
        
        function im = chooseColor(obj, frame, color)
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
        
        function out = normalize(obj, in)
            z = in-min(in(:)); % make baseline 0
            out = z/max(z(:));
        end
        
        function roi = getROI(obj)
            roi = findobj(obj.gui.fig, 'Tag', 'ROI');
        end
        
        function updateSidebar(obj)
            xticks = [ceil(min(xlim)) round(mean(xlim)) floor(max(xlim))];
            yticks = [ceil(min(ylim)) round(mean(ylim)) floor(max(ylim))];
            
            obj.gui.x_start.String = sprintf('%dpx', xticks(1));
            obj.gui.x_end.String = sprintf('%dpx', xticks(3));
            obj.gui.x_zoom.String = sprintf('%1.2fx', size(obj.curr_image, 2)/diff(xlim));
            
            obj.gui.y_start.String = sprintf('%dpx', yticks(1));
            obj.gui.y_end.String = sprintf('%dpx', yticks(3));
            obj.gui.y_zoom.String = sprintf('%1.2fx', size(obj.curr_image, 1)/diff(ylim));
        end
        
        
        %% Clean up and saving functions %%
        function finalize(obj)
            % get rid of the close req fcn
            obj.gui.fig.DeleteFcn = []; % so it doesn't run the abort function as well
            
            commandwindow
            fprintf('Found %d cells.\n', obj.curr_cell-1);
            
            % dilate poly masks before saving
            [m,n]=size(obj.green);
            for j = 1:length(obj.cell_masks)
                position=obj.cell_masks{j};
                tempmask=imdilate(poly2mask(position(:,1),position(:,2),m,n),ones(3));
                newmask = bwboundaries(tempmask,4,'noholes');
                if ~isempty(newmask)
                    obj.cell_masks{j} = newmask{1}(:,[2,1]);
                else
                    obj.cell_masks{j} = NaN;
                end
            end
            removemasks = cellfun(@(x) max(isnan(x(:))),obj.cell_masks);
            obj.cell_masks(removemasks)=[];
        end
        
        function save(obj)
            % append or overwrite?
            if obj.curr_cell-1 == 0
                obj.savemode = 0;
            elseif isfield(obj.data,'cellMasks')
                if ~iscell(obj.data.cellMasks)
                    % convert BW masks to poly and dilate
                    oldCellMasks = cell(1,max(obj.data.cellMasks(:)));
                    for j = 1:max(obj.data.cellMasks(:))
                        tempmask = imdilate(obj.data.cellMasks==j,ones(3));
                        newmask = bwboundaries(tempmask,4,'noholes');
                        if ~isempty(newmask)
                            oldCellMasks{j} = newmask{1}([2,1]);
                        else
                            oldCellMasks{j} = [0,0];
                        end
                    end
                    obj.data.cellMasks = oldCellMasks;
                end
                
                fprintf('File already has %d cell masks.\n',length(obj.data.cellMasks));
                
                obj.savemode = input('Append (2), Overwrite (1), or Cancel (0)? ');
            else
                obj.savemode = input('Save (1), or Cancel (0)? ');
            end
            
            if obj.savemode == 2
                obj.data.cellMasks = [obj.data.cellMasks,obj.cell_masks];
                data = obj.data;
                save(sprintf('%s_data.mat', obj.filename(1:end-9)), 'data');
                % 				eval(['save ' obj.filename(1:end-9) '_data obj.data']);
                disp('File saved')
            elseif obj.savemode == 1
                obj.data.cellMasks=obj.cell_masks; % save poly masks
                data = obj.data;
                save(sprintf('%s_data.mat', obj.filename(1:end-9)), 'data');
                disp('File saved')
            else
                disp('File not saved')
                obj.filename = [];
            end
            
            pause(1)
            close
        end
        
        function saveAutodetect(obj)
            keep = questdlg('Keep autodetected cells?','Keep autodetected cells?','Yes','No','Cancel','Yes');
            drawnow % pop up the dialog
            switch keep
                case 'Yes'
                    newMasks = bwboundaries(obj.autodetect_masks,4,'noholes')';
                    for j = 1:length(newMasks)
                        newMasks{j}(:,[1,2]) = newMasks{j}(:,[2,1]); % switch to [X,Y], instead of [r,c]
                    end
                    obj.cell_masks = [obj.cell_masks, newMasks];
                    obj.curr_cell = length(obj.cell_masks)+1;
                    obj.masks = obj.masks+obj.autodetect_masks;
                    obj.autodetect_masks(:,:) = 0;
                    set(obj.gui.([obj.autodetect_map 'Auto']),'Enable','off');
                case 'No'
                    obj.autodetect_masks(:,:) = 0;
                    set(obj.gui.([obj.autodetect_map 'Auto']),'Value',0);
                    obj.update();
            end
        end
        
        %% Button callbacks %%
        
        function changeMode(obj, ~, ~)
            if ~obj.killed
                switch obj.getCurrentMode()
                    case 'Ellipse'
                        zoom off;
                        pan off;
                        drawellipse('Tag', 'ROI', 'DrawingArea', 'unlimited'); % needs tags so MATLAB can find and delete them 24Jan2022 KS
                    case 'Freehand'
                        zoom off;
                        pan off;
                        drawfreehand('Tag', 'ROI', 'DrawingArea', 'unlimited');
                    case 'Zoom'
                        zoom on;
                        h = zoom;
                        set(h,'ActionPostCallback',@obj.replot)
                    case 'Pan'
                        pan on;
                        h = pan;
                        set(h,'ActionPostCallback',@obj.replot)
                end
                % need a second killed here in case its already entered the
                % loop...
                if ~obj.killed && (strcmp(obj.getCurrentMode(), 'Ellipse') || strcmp(obj.getCurrentMode(), 'Freehand')) % terminate, so we don't move forward here
                    set(obj.gui.fig, 'WindowButtonDownFcn', @obj.updateMask)
                    set(obj.gui.fig, 'KeyPressFcn', @obj.cancelROI)
                else 
                    return;
                end
            else
                return; % kill it at the end
            end
        end
        
        function requestModeChange(obj, ~, ~) % deletes previous ROI then allows next one to be drawn 24Jan2022 KS
            if strcmp(obj.getCurrentMode(), 'Ellipse') || strcmp(obj.getCurrentMode(), 'Freehand') % for the ROIs, need to clean old ones
                obj.clearROIs();
            end
            obj.resumeAll();
            obj.changeMode();
        end
        
        function finishButtonPressed(obj, ~, ~)
            % Triggers when the finish button is pressed, used for both
            % ending GUI as well as completing autodetect
            obj.clearROIs();
            if max(obj.autodetect_masks(:))>0 % for autodetect
                obj.saveAutodetect();
                obj.update();
            else
                obj.finalize();
                obj.save();
                obj.kill();
            end
        end
        
        function autoDetect(obj, src, ~)
            obj.autodetect_map = get(src,'Tag');
            if max(obj.autodetect_masks(:))>0
                currvalue = get(obj.gui.([obj.autodetect_map 'Auto']),'Value');
                set(obj.gui.([obj.autodetect_map 'Auto']),'Value',~currvalue);
                
            elseif get(obj.gui.([obj.autodetect_map 'Auto']),'Value') == 1 % checknig which box is checked
                prompt = {'Threshold offset:','Threshold window','Min pixels','Max Pixels','H_maxima'};
                obj.autodetect_params = inputdlg(prompt,'Parameters',1,obj.default_parameters);
                params = cellfun(@str2double, obj.autodetect_params);
                if ~isempty(params)
                    [obj.autodetect_masks] = subroutine_autodetect(obj.(obj.autodetect_map), params);
                else
                    set(obj.([obj.autodetect_map 'Auto']),'Value',0);
                end
                
            end
            obj.update();
        end
        
        function reset(obj, ~, ~)
            axis(obj.gui.img_axis, [1, size(obj.green, 1), 1, size(obj.green, 2)]);
            obj.update();
        end
        
        function cancelROI(obj, ~, evt)
            if strcmp(evt.Key, 'escape')
                obj.clearROIs();
                obj.update();
                set(obj.gui.fig, 'KeyPressFcn', @obj.cancelROI)
            end
        end
        
        %% Other callbacks %%
        
        function replot(obj, ~, ~)
            if ~obj.killed
                % update labels
                current_lims = axis(obj.gui.img_axis);
                set(obj.gui.greenLabel,'String',sprintf('%1.1f',get(obj.gui.greenGain,'Value')));
                set(obj.gui.amapLabel,'String',sprintf('%1.1f',get(obj.gui.amapGain,'Value')));
                set(obj.gui.masksLabel,'String',sprintf('%1.1f',get(obj.gui.masksGain,'Value')));
                
                green = get(obj.gui.greenOn,'Value')*obj.chooseColor(obj.green,get(obj.gui.greenColor,'Value'));
                amap = get(obj.gui.amapOn,'Value')*obj.chooseColor(obj.amap,get(obj.gui.amapColor,'Value'));
                masks = get(obj.gui.masksOn,'Value')*obj.chooseColor(obj.masks+obj.autodetect_masks,get(obj.gui.masksColor,'Value'));
                
                obj.curr_image= get(obj.gui.greenGain,'Value')*green + get(obj.gui.amapGain,'Value')*amap ...
                    + get(obj.gui.masksGain,'Value')*masks;
                obj.curr_image(obj.curr_image>1) = 1;
                image(obj.gui.img_axis, obj.curr_image)
                axis(obj.gui.img_axis, 'square');
                if ~all(current_lims == [0 1 0 1])
                    axis(current_lims)
                end
                if max(obj.autodetect_masks(:))>0
                    title('Press "Finished" to confirm/reject autodetected cells.')
                else
                    title(sprintf('cells found: %d',obj.curr_cell-1))
                end
                
                obj.updateSidebar();
                set(obj.gui.img_axis,'XTick', [])
                set(obj.gui.img_axis,'YTick', [])
                set(obj.gui.img_axis, 'Toolbar', []);
            else
                return;
            end
        end
        
        function updateMask(obj, src, ~)
            if strcmp(get(src,'SelectionType'),'open') % require double click
                obj.resumeAll(); % resume after drawing and double clicking
                if ~isempty(obj.getROI()) && isvalid(obj.getROI())
                    roi = obj.getROI();
                    if strcmp(obj.getCurrentMode(), 'Freehand') % freehand
                        position = roi.Position;
                    else
                        position = roi.Vertices; % ellipse
                    end
                    if ~isempty(position)
                        [m,n]=size(obj.green);
                        mask_disp=poly2mask(position(:,1),position(:,2),m,n);
                        
                        % check for complete encompassing of mask
                        in = [];
                        for j = 1:length(obj.cell_masks)
                            if min(mask_disp(poly2mask(obj.cell_masks{j}(:,1),...
                                    obj.cell_masks{j}(:,2),m,n)))==1
                                in = [in, j];
                            end
                        end
                        if isempty(in)
                            % update cell mask matrix
                            obj.cell_masks{obj.curr_cell}=position;
                            obj.curr_cell=obj.curr_cell+1;
                            
                            % update display image
                            obj.masks=obj.masks+mask_disp;
                        else
                            % delete cell masks
                            for j = 1:length(in)
                                removemask = poly2mask(obj.cell_masks{in(j)}(:,1),obj.cell_masks{in(j)}(:,2),m,n);
                                removemask = imdilate(removemask,ones(3));
                                obj.masks(removemask) = 0;
                            end
                            
                            obj.cell_masks(in) = [];
                            obj.curr_cell = obj.curr_cell-length(in);
                        end
                        obj.update();
                    end
                end
            end
        end
        
        function abort(obj, ~, ~)
            obj.curr_cell = 1;
            obj.autodetect_masks(:) = 0;
            disp('Figure closed -- masks not saved.')
            obj.filename = [];
            obj.kill();
        end
        
        %% Build GUI %%
        function buildGUI(obj)
            obj.gui.fig = figure;
            obj.gui.fig.Position = [300, 100, 950, 950];
            obj.gui.fig.Color = [1, 1, 1];
            
            obj.gui.greenOn = uicontrol(obj.gui.fig,'Value',1,'Style','togglebutton',...
                'Units','characters','Position',[obj.L 6 20 2],'String','Avg Projection',...
                'Callback',@obj.replot);
            obj.gui.amapOn = uicontrol(obj.gui.fig,'Value',1,'Style','togglebutton',...
                'Units','characters','Position',[obj.L+obj.S 6 20 2],'String','Activity Map',...
                'Callback',@obj.replot);
            obj.gui.masksOn = uicontrol(obj.gui.fig,'Value',1,'Style','togglebutton',...
                'Units','characters','Position',[obj.L+2*obj.S 6 20 2],'String','Masks',...
                'Callback',@obj.replot);
            
            obj.gui.greenColor = uicontrol(obj.gui.fig,'Style','popupmenu',...
                'String',{'Grey','Red','Green','Blue'},'Value',1,'Units','characters',...
                'Position',[obj.L 5 20 1],'Callback',@obj.replot);
            obj.gui.amapColor = uicontrol(obj.gui.fig,'Style','popupmenu',...
                'String',{'Grey','Red','Green','Blue'},'Value',2,'Units','characters',...
                'Position',[obj.L+obj.S 5 20 1],'Callback',@obj.replot);
            obj.gui.masksColor = uicontrol(obj.gui.fig,'Style','popupmenu',...
                'String',{'Grey','Red','Green','Blue'},'Value',4,'Units','characters',...
                'Position',[obj.L+2*obj.S 5 20 1],'Callback',@obj.replot);
            
            obj.gui.greenGain = uicontrol(obj.gui.fig,'Style','slider','Max',1.5,'SliderStep',[0.1 0.3]/1.5,...
                'Value',0.4,'Units','characters','Position',[obj.L 3 20 1],'Callback',@obj.replot);
            obj.gui.amapGain = uicontrol(obj.gui.fig,'Style','slider','Max',1.5,'SliderStep',[0.1 0.3]/1.5,...
                'Value',1,'Units','characters','Position',[obj.L+obj.S 3 20 1],'Callback',@obj.replot);
            obj.gui.masksGain = uicontrol(obj.gui.fig,'Style','slider','Max',1.5,'SliderStep',[0.1 0.3]/1.5,...
                'Value',1,'Units','characters','Position',[obj.L+2*obj.S 3 20 1],'Callback',@obj.replot);
            
            obj.gui.greenLabel = uicontrol(obj.gui.fig,'Style','text',...
                'String','0.4','Units','characters','Position',[obj.L 2 20 1]);
            obj.gui.amapLabel = uicontrol(obj.gui.fig,'Style','text',...
                'String','0.4','Units','characters','Position',[obj.L+obj.S 2 20 1]);
            obj.gui.masksLabel = uicontrol(obj.gui.fig,'Style','text',...
                'String','0.4','Units','characters','Position',[obj.L+2*obj.S 2 20 1]);
            
            obj.gui.greenAuto = uicontrol(obj.gui.fig,'Style','checkbox','Tag','green',...
                'String','Auto Detect','Units','characters','Position',[obj.L 1 20 1],'Callback',@obj.autoDetect);
            obj.gui.amapAuto = uicontrol(obj.gui.fig,'Style','checkbox','Tag','amap',...
                'String','Auto Detect','Units','characters','Position',[obj.L+obj.S 1 20 1],'Callback',@obj.autoDetect);
            
            obj.gui.reset = uicontrol(obj.gui.fig,'Style','pushbutton','Units','characters',...
                'Position',[obj.L+4*obj.S-5 5.5 20 2],'String','Reset View','Callback',@obj.reset);
            
            obj.gui.finished = uicontrol(obj.gui.fig,'Style','pushbutton','Units','characters',...
                'Position',[obj.L+4*obj.S-5 1.5 20 3],'String','Finished','Callback',@obj.finishButtonPressed);
            
            % Changed to a toggle button group because it can detect changes better 24Jan2022 KS
            obj.gui.modeSelect = uibuttongroup(obj.gui.fig, 'Units', 'characters', 'Position', [obj.L+3*obj.S, 1, 20, 8], 'SelectionChangedFcn', @obj.requestModeChange);
            uicontrol(obj.gui.modeSelect, 'Units', 'normalized', 'Position', [0.1, 0.7, 0.8, 0.2], 'Style', 'togglebutton', 'String', 'Ellipse');
            uicontrol(obj.gui.modeSelect, 'Units', 'normalized', 'Position', [0.1, 0.5, 0.8, 0.2], 'Style', 'togglebutton', 'String', 'Freehand');
            uicontrol(obj.gui.modeSelect, 'Units', 'normalized', 'Position', [0.1, 0.3, 0.8, 0.2], 'Style', 'togglebutton', 'String', 'Zoom'); % comments
            uicontrol(obj.gui.modeSelect, 'Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.2], 'Style', 'togglebutton', 'String', 'Pan');
            
            obj.gui.img_axis = axes(obj.gui.fig);
            axis(obj.gui.img_axis, [1, size(obj.green, 1), 1, size(obj.green, 2)]);
            
            obj.gui.x_info = uipanel(obj.gui.fig, 'Title', 'X', 'FontSize', 15, 'Units', 'characters', 'Position', [1, 18, 22, 15]);
            obj.gui.y_info = uipanel(obj.gui.fig, 'Title', 'Y', 'FontSize', 15, 'Units', 'characters', 'Position', [1, 2, 22, 15]);
            % making the labels
            uicontrol(obj.gui.x_info, 'Style', 'Text','FontSize', 10, 'Units','normalized', 'Position', [-0.23, 0.9, 1, 0.1], 'String', 'Start')
            uicontrol(obj.gui.x_info, 'Style', 'Text','FontSize', 10, 'Units','normalized', 'Position', [-0.26, 0.6, 1, 0.1], 'String', 'End')
            uicontrol(obj.gui.x_info, 'Style', 'Text', 'FontSize', 10,'Units','normalized', 'Position', [-0.2, 0.3, 1, 0.1], 'String', 'Zoom')
            
            uicontrol(obj.gui.y_info, 'Style', 'Text','FontSize', 10, 'Units','normalized', 'Position', [-0.23, 0.9, 1, 0.1], 'String', 'Start')
            uicontrol(obj.gui.y_info, 'Style', 'Text','FontSize', 10, 'Units','normalized', 'Position', [-0.26, 0.6, 1, 0.1], 'String', 'End')
            uicontrol(obj.gui.y_info, 'Style', 'Text', 'FontSize', 10,'Units','normalized', 'Position', [-0.2, 0.3, 1, 0.1], 'String', 'Zoom')
            
            % editable fields now:
            obj.gui.x_start = uicontrol(obj.gui.x_info, 'Style', 'Text', 'FontSize', 12, 'Units','normalized', 'Position', [0, 0.75, 1, 0.15], 'String', '0');
            obj.gui.x_end = uicontrol(obj.gui.x_info, 'Style', 'Text', 'FontSize', 12, 'Units','normalized', 'Position', [0, 0.45, 1, 0.15], 'String', '0');
            obj.gui.x_zoom = uicontrol(obj.gui.x_info, 'Style', 'Text', 'FontSize', 12, 'Units','normalized', 'Position', [0, 0.15, 1, 0.15], 'String', '0');
            
            obj.gui.y_start = uicontrol(obj.gui.y_info, 'Style', 'Text', 'FontSize', 12, 'Units','normalized', 'Position', [0, 0.75, 1, 0.15], 'String', '0');
            obj.gui.y_end = uicontrol(obj.gui.y_info, 'Style', 'Text', 'FontSize', 12, 'Units','normalized', 'Position', [0, 0.45, 1, 0.15], 'String', '0');
            obj.gui.y_zoom = uicontrol(obj.gui.y_info, 'Style', 'Text', 'FontSize', 12, 'Units','normalized', 'Position', [0, 0.15, 1, 0.15], 'String', '0');
            
            
            obj.gui.fig.DeleteFcn = @obj.abort;
        end
    end
end
