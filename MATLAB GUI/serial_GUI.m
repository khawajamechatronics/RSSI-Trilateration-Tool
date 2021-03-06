function varargout = serial_GUI(varargin)

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @serial_GUI_OpeningFcn, ...
                   'gui_OutputFcn',  @serial_GUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before serial_GUI is made visible.
function serial_GUI_OpeningFcn(hObject, eventdata, handles, varargin)

serialPorts = instrhwinfo('serial');
nPorts = length(serialPorts.SerialPorts);
set(handles.portList, 'String', ...
    [{'Select a port'} ; serialPorts.SerialPorts ]);
set(handles.portList, 'Value', 2); 

% Initialize Variables
settings = textread('nodesettings.txt','%s');
numOfNodes = length(settings)/3;    % 3 elements per node
handles.nodeData(numOfNodes) = struct('addr',[],'pos',[]);
for ii = 1:numOfNodes
    handles.nodeData(ii).addr = char(settings(ii*3 - 2));
    handles.nodeData(ii).pos = [str2num(cell2mat(settings(ii*3 - 1))),str2num(cell2mat(settings(ii*3)))];
end
handles.mobileData = struct('addr',[],'pos',[]);    % Struct for storing mobile node info

% Populate anchor list box contents
nodeString = [];
for ii = 1:numOfNodes
    nodeString = [nodeString;{sprintf('%s [%.2f,%.2f]',handles.nodeData(ii).addr,handles.nodeData(ii).pos(1),handles.nodeData(ii).pos(2))}]; 
end
set(handles.anchorlist, 'string', nodeString);

% Get Log-Distance Path Loss model settings
settings = textread('modelsettings.txt','%s');
handles.n = str2num(cell2mat(settings(1)));
handles.A = str2num(cell2mat(settings(2)));
set(handles.pathLossEdit,'string',(handles.n));
set(handles.refEdit,'string', (handles.A));

% Avg filtering and rssi history variables
handles.avgfiltlen = 10;
handles.histlen = 11;   % min val is avgfiltlen + 1

plotNodes(hObject,handles)
handles.output = hObject;

% Set up plotting function
% handles.t = timer('StartDelay', 0, 'Period', 1, 'TasksToExecute', Inf, ...
%             'ExecutionMode', 'fixedRate');
% handles.t.TimerFcn = {@updatePlot, hObject, handles};

% Update handles structure
guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = serial_GUI_OutputFcn(hObject, eventdata, handles) 

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on selection change in portList.
function portList_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.

function portList_CreateFcn(hObject, eventdata, handles)

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function baudRateText_Callback(hObject, eventdata, handles)
% hObject    handle to baudRateText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes during object creation, after setting all properties.
function baudRateText_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in connectButton.
function connectButton_Callback(hObject, eventdata, handles)    
if strcmp(get(hObject,'String'),'Connect') % currently disconnected
    serPortn = get(handles.portList, 'Value');
    if serPortn == 1
        errordlg('Select valid COM port');
    else
        serList = get(handles.portList,'String');
        serPort = serList{serPortn};
        serConn = serial(serPort, 'TimeOut', 1, ...
            'BaudRate', str2num(get(handles.baudRateText, 'String')));
        
         serConn.BytesAvailableFcnCount = 1;
         serConn.BytesAvailableFcnMode = 'byte';
         serConn.BytesAvailableFcn = {@serial_callback, hObject, handles};
        
        try
            fopen(serConn);
            handles.serConn = serConn;
            
            set(hObject, 'String','Disconnect') 
            % Ghost out options that cannot be changed once application is
            % connected
            % Path Loss Model: 
            set(handles.pathLossDefaultButton,'Enable','off');
            set(handles.pathLossEdit,'Enable','off');
            set(handles.refEdit,'Enable','off');
            % Anchor Node Info:
            set(handles.anchorlist,'Enable','off');
            set(handles.addAnchorButton,'Enable','off');
            set(handles.setDefaultButton,'Enable','off');
            set(handles.deleteAnchorButton,'Enable','off');
            
        catch e
            errordlg(e.message);
        end       
    end
else  
    set(hObject, 'String','Connect')
    fclose(handles.serConn);
    % Restore Ghosted Options
    % Path Loss Model: 
    set(handles.pathLossDefaultButton,'Enable','on');
    set(handles.pathLossEdit,'Enable','on');
    set(handles.refEdit,'Enable','on');
    % Anchor Node Info:
    set(handles.anchorlist,'Enable','on');
    set(handles.addAnchorButton,'Enable','on');
    set(handles.setDefaultButton,'Enable','on');
    set(handles.deleteAnchorButton,'Enable','on');
end
guidata(hObject, handles);

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isfield(handles, 'serConn')
    fclose(handles.serConn);
end
% Hint: delete(hObject) closes the figure
delete(hObject);

% --- Executes on button press in print_nodes.
function print_nodes_Callback(hObject, eventdata, handles)
% hObject    handle to print_nodes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
for ii = 1:length(handles.nodeData)
    if(~isempty(handles.nodeData(ii).addr))
        handles.nodeData(ii)
    end
end

% Update handles structure
guidata(hObject, handles);


% --- Executes on selection change in anchorlist.
function anchorlist_Callback(hObject, eventdata, handles)

% Hints: contents = cellstr(get(hObject,'String')) returns anchorlist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from anchorlist
handles = guidata(hObject);
% Get list values
val = get(handles.anchorlist,'String');
idx = get(handles.anchorlist,'Value');
% Generate Dialogue box to get user input
prompt = {'Enter Last 4 Bytes of MAC Address:','Enter X Location:','Enter Y Location:'};
dlg_title = 'Edit Anchor Node Address and Location';
num_lines = 1;
% Remove brackets and split string into 3 strings: addr, x, and y
tmp = char(val(idx,:));
tmp = tmp(tmp ~= '[');
tmp = tmp(tmp ~= ']');
tmp = strsplit(tmp,{' ',','});
defaultans = {char(tmp(1)),char(tmp(2)),char(tmp(3))};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
% Put user input into nodeData structure
if(~isempty(answer))
    handles.nodeData(idx).addr = char(answer(1));
    handles.nodeData(idx).pos(1) = str2double(cell2mat(answer(2)));
    handles.nodeData(idx).pos(2) = str2double(cell2mat(answer(3)));
    guidata(hObject, handles);
    plotNodes(hObject,handles);
    % Populate anchor list box contents
    nodeString = [];
    for ii = 1:length(handles.nodeData)
        nodeString = [nodeString;{sprintf('%s [%.2f,%.2f]',handles.nodeData(ii).addr,handles.nodeData(ii).pos(1),handles.nodeData(ii).pos(2))}]; 
    end
    set(handles.anchorlist, 'string', nodeString);
end



% --- Executes during object creation, after setting all properties.
function anchorlist_CreateFcn(hObject, eventdata, handles)

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in addAnchorButton.
function addAnchorButton_Callback(hObject, eventdata, handles)
handles = guidata(hObject);
% Generate Dialogue box to get user input
prompt = {'Enter Last 4 Bytes of MAC Address:','Enter X Location:','Enter Y Location:'};
dlg_title = 'Anchor Node Address and Location';
num_lines = 1;
defaultans = {'40F7569E','0','0'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
% Put user input into nodeData structure
idx = length(handles.nodeData) + 1;
handles.nodeData(idx).addr = char(answer(1));
handles.nodeData(idx).pos(1) = str2num(cell2mat(answer(2)));
handles.nodeData(idx).pos(2) = str2num(cell2mat(answer(2)));
guidata(hObject, handles);
plotNodes(hObject,handles);
% Populate anchor list box contents
nodeString = [];
for ii = 1:idx
%     nodeString = sprintf('%s%s [%.2f,%.2f] \n',nodeString,handles.nodeData(ii).addr,handles.nodeData(ii).pos(1),handles.nodeData(ii).pos(2)); 
    nodeString = [nodeString;{sprintf('%s [%.2f,%.2f]',handles.nodeData(ii).addr,handles.nodeData(ii).pos(1),handles.nodeData(ii).pos(2))}]; 

end
set(handles.anchorlist, 'string', nodeString);


% --- Executes on button press in setDefaultButton.
function setDefaultButton_Callback(hObject, eventdata, handles)

answer = 0;
choice = questdlg('Are you sure you want to save the current anchor node configuration as the default values?','Save Anchor Configuration','Yes','No','No');
% Handle response
switch choice
    case 'Yes'
        disp('Saving configuration...')
        answer = 1;
    case 'No'
        answer = 0;
end
if( answer > 0 )
    val = char(get(handles.anchorlist,'String'));
    fid = fopen('nodesettings.txt', 'w');

    buf = [];
    tmp = [];
    for ii = 1:length(handles.nodeData)
        %throw out brackets and commas
        tmp = val(ii,:);
        tmp = tmp(tmp ~= '[');
        tmp = tmp(tmp ~= ']');
        tmp(tmp == ',') = ' ';
        buf = sprintf('%s%s ',buf,tmp);
    end

    fprintf(fid, '%s', buf);
    fclose(fid); 
end


% --- Executes on button press in deleteAnchorButton.
function deleteAnchorButton_Callback(hObject, eventdata, handles)
handles = guidata(hObject);
if(length(handles.nodeData) < 4)
    msgbox('Cannot have less than 3 Anchor nodes!','Trilateration Error');
else
    val = get(handles.anchorlist,'String');
    idx = get(handles.anchorlist,'Value');
    val(idx,:) = [];
    if(~isempty(val))
        set(handles.anchorlist, 'String', val );
    end

    % Move indices up to fill in space from deleted node
    for ii = idx:length(handles.nodeData)
        handles.nodeData(idx) = handles.nodeData(idx + 1);
    end
    handles.nodeData(length(handles.nodeData)).addr = [];
    handles.nodeData(length(handles.nodeData)).rssi = [];
    handles.nodeData(length(handles.nodeData)).pos = [];
    handles.nodeData(length(handles.nodeData)).dist = [];
    handles.nodeData(length(handles.nodeData)).freshness = 0;
    handles.nodeData(length(handles.nodeData)) = [];

    guidata(hObject, handles);
    plotNodes(hObject,handles);
end
        



function pathLossEdit_Callback(hObject, eventdata, handles)

% Hints: get(hObject,'String') returns contents of pathLossEdit as text
%        str2double(get(hObject,'String')) returns contents of pathLossEdit as a double
 handles.n = str2double(get(hObject,'String'));  % Get the value entered in your editbox
 if(handles.n > 10)
     msgbox('This value seems high for a path loss exponent. Try something lower!','Model Warning');
 end
 guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function pathLossEdit_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function refEdit_Callback(hObject, eventdata, handles)
% Hints: get(hObject,'String') returns contents of refEdit as text
%        str2double(get(hObject,'String')) returns contents of refEdit as a double
 handles.A = str2double(get(hObject,'String'));  % Get the value entered in your editbox
 guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function refEdit_CreateFcn(hObject, eventdata, handles)
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pathLossDefaultButton.
function pathLossDefaultButton_Callback(hObject, eventdata, handles)
fid = fopen('modelsettings.txt', 'w');

buf = sprintf('%.2f %d',handles.n,handles.A);

fprintf(fid, '%s', buf);
fclose(fid); 


% --- Executes on button press in nofiltbutton.
function nofiltbutton_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of nofiltbutton

% Get states of other radiobuttons
if(get(handles.avgfiltbutton,'Value'))
    set(handles.avgfiltbutton,'Value',0);
end
 guidata(hObject, handles);


% --- Executes on button press in figSave.
function figSave_Callback(hObject, eventdata, handles)
% Generate Dialogue box to get user input
if(~(isfield(handles,'saveCount')))
    handles.saveCount = 0;
end
prompt = {'Enter filename:'};
dlg_title = 'Save';
num_lines = 1;
defaultans = {sprintf('Figure%d',handles.saveCount + 1)};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
if(~isempty(answer))
    handles.saveCount = handles.saveCount + 1;
    h = handles.nodes_axes;
    hgsave(h, char(answer));
end
guidata(hObject, handles);

% --- Executes on button press in avgfiltbutton.
function avgfiltbutton_Callback(hObject, eventdata, handles)
% Hint: get(hObject,'Value') returns toggle state of avgfiltbutton
if(get(handles.nofiltbutton,'Value'))
    set(handles.nofiltbutton,'value',0);
end
set(handles.avgfiltbutton,'Value',1);
% Prompt user for number of samples to average
prompt = {'Average how many samples? Warning: if value does not save, disconnect the serial port.'};
dlg_title = 'Sample Size';
num_lines = 1;
defaultans = {num2str(handles.avgfiltlen)};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
if(~isempty(answer))
    handles.avgfiltlen = str2double(cell2mat(answer(1)));
else
    handles.avgfiltlen = 10;
end
% Clear sample history each time filtering mode is changed
if(~isempty(handles.mobileData.addr))   % Can't modify mobile node parameters if a mobile node hasn't been connected yet
    for ii = 1:length(handles.mobileData)
        for jj = 1:length(handles.mobileData(ii).anchorData)
            handles.mobileData(ii).anchorData(jj).rssiAvg = 0;
        end
    end
end
        
guidata(hObject, handles);


% --- Executes on button press in mobilePollButton.
function mobilePollButton_Callback(hObject, eventdata, handles)
status = get(handles.connectButton,'String');
if(strcmp(status , 'Disconnect'))   % button displays 'Disconnect' if connected to a port
    if(~isfield(handles,'delayTime'))
        handles.delayTime = 10;
    end
    prompt = {'Set time (in ms) between mobile node to anchor node measurements:'};
    dlg_title = 'Polling Time';
    num_lines = 1;
    defaultans = {num2str(handles.delayTime)};
    answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
    if(~isempty(answer))
        handles.delayTime = str2double(cell2mat(answer(1)));
        fwrite(handles.serConn,char([uint8(hex2dec('FD')),uint8(handles.delayTime)]));
    end
else
    msgbox('Not connected to a mobile node!','Warning');
end


% --- Executes on mouse press over axes background.
function nodes_axes_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to nodes_axes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
persistent chk;
if isempty(chk)
      chk = 1;
      pause(0.5); %Add a delay to distinguish single click from a double click
      if chk == 1
          %fprintf(1,'\nI am doing a single-click.\n\n');
          chk = [];
      end
else
       chk = [];
      %fprintf(1,'\nI am doing a double-click.\n\n');
      % Generate Dialogue box to get user input
      prompt = {'Enter X Location:','Enter Y Location:','Add Label:'};
      dlg_title = 'Add Point';
      num_lines = 1;
      defaultans = {'0','0',' '};
      answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
      if(~isempty(answer))
          if(~isfield(handles,'points'))
              handles.points = [];
              handles.points(1,:) = [str2double(cell2mat(answer(1))), str2double(cell2mat(answer(2)))];
              handles.pointslabel(1) = answer(3);
          else
              [len, ~] = size(handles.points);
              handles.points(len + 1,:) = [str2double(cell2mat(answer(1))), str2double(cell2mat(answer(2)))];
              handles.pointslabel(len + 1) = answer(3);
          end
      end
      plotNodes(hObject,handles);
end


% --- Executes on button press in clearUserPointsButton.
function clearUserPointsButton_Callback(hObject, eventdata, handles)
% hObject    handle to clearUserPointsButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if(isfield(handles,'points'))
    handles = rmfield(handles,'points');
    handles = rmfield(handles,'pointslabel');
end
plotNodes(hObject,handles);
guidata(hObject, handles);


% --- Executes on button press in posHistCheckbox.
function posHistCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to posHistCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of posHistCheckbox


% --- Executes on selection change in mobileNodeList.
function mobileNodeList_Callback(hObject, eventdata, handles)
% hObject    handle to mobileNodeList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns mobileNodeList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from mobileNodeList
handles = guidata(hObject);
% Get list values
val = get(handles.mobileNodeList,'String');
idx = get(handles.mobileNodeList,'Value');
% Generate Dialogue box to get user input
if(~isempty(handles.mobileData(1).addr))
    msg = {sprintf('Address: %s\n   Position: %0.2f, %0.2f, \n',char(val), handles.mobileData(idx).pos(1), handles.mobileData(idx).pos(2))};
    if(isfield(handles.mobileData(idx),'anchorData'))
        msg = {sprintf('%sConnected Anchors:\n',char(msg))};
        msg2 = {''};
        msg3 = {''};
        for ii = 1:length(handles.mobileData(idx).anchorData)
            if(get(handles.avgfiltbutton,'Value'))
                msg2 = {sprintf('%s %s\n    RSSI: %0.2f -dBm\n    Distance: %0.2f\n',char(msg2),handles.mobileData(idx).anchorData(ii).addr,handles.mobileData(idx).anchorData(ii).rssiAvg, handles.mobileData(idx).anchorData(ii).dist)};
                if(length(handles.mobileData(idx).anchorData(ii).rssi) >= handles.avgfiltlen)
                    msg2 = {sprintf('%s    Variance: %0.2f\n',char(msg2),var(handles.mobileData(idx).anchorData(ii).rssi))};
                else
                    msg2 = {sprintf('%s    Variance: %0.2f\n',char(msg2),var(handles.mobileData(idx).anchorData(ii).rssi(1:end)))};
                end
            else
                msg2 = {sprintf('%s %s\n    RSSI: %d -dBm\n    Distance: %0.2f\n',char(msg2),handles.mobileData(idx).anchorData(ii).addr,handles.mobileData(idx).anchorData(ii).rssi(end), handles.mobileData(idx).anchorData(ii).dist)};
                if(length(handles.mobileData(idx).anchorData(ii).rssi) >= handles.avgfiltlen)
                    msg2 = {sprintf('%s    Variance: %0.2f\n',char(msg2),var(handles.mobileData(idx).anchorData(ii).rssi))};
                else
                    msg2 = {sprintf('%s    Variance: %0.2f\n',char(msg2),var(handles.mobileData(idx).anchorData(ii).rssi(1:end)))};
                end
            end 
        end
        msg = {sprintf('%s%s',char(msg),char(msg2),char(msg3))};
    end
    msgbox(msg,'Mobile Node Info');
end

% --- Executes during object creation, after setting all properties.
function mobileNodeList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to mobileNodeList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in drawCirclesCheck.
function drawCirclesCheck_Callback(hObject, eventdata, handles)
% hObject    handle to drawCirclesCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of drawCirclesCheck


% --- Executes on button press in pointButton.
function pointButton_Callback(hObject, eventdata, handles)
% hObject    handle to pointButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
prompt = {'Enter X Location:','Enter Y Location:','Add Label:'};
dlg_title = 'Add Point';
num_lines = 1;
defaultans = {'0','0',' '};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
if(~isempty(answer))
  if(~isfield(handles,'points'))
      handles.points = [];
      handles.points(1,:) = [str2double(cell2mat(answer(1))), str2double(cell2mat(answer(2)))];
      handles.pointslabel(1) = answer(3);
  else
      [len, ~] = size(handles.points);
      handles.points(len + 1,:) = [str2double(cell2mat(answer(1))), str2double(cell2mat(answer(2)))];
      handles.pointslabel(len + 1) = answer(3);
  end
end
plotNodes(hObject,handles);
