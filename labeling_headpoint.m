% MATLAB Script for Video Frame Editing and Point Annotation
%
% This script allows users to select a video file and its associated audio and coordinate data.
% It processes the audio to find frames with significant audio events (e.g., loud sounds),
% extracts specific segments from the video, and provides a GUI for annotating points on each frame.
%
% The GUI supports navigation through frames and segments, point marking via mouse clicks,
% and automatic navigation to unmarked frames. The annotated points are saved to a MAT file.
%
% Instructions:
% - Run the script in MATLAB.
% - Select the desired video file when prompted.
% - Use the left and right arrow keys to navigate frames.
% - Click on the frame to mark a point.
% - The script will automatically proceed to unmarked frames.
% - Close the GUI to save the annotated points.

clc
clear
clear global

global globalPointPositions;

[videoFileName, videoPath] = uigetfile({'*.avi'},...
    'Select a video file', 'D:\PSW trace video\included_data\');
audioFileName = [videoFileName(1:end-3) 'mp3'];  % Assuming video file is .avi
audioPath = 'D:\PSW trace video\';
videoFile = fullfile(videoPath, videoFileName);
audioFile = fullfile(audioPath, audioFileName);
csvFileName = [videoFileName(1:end-4) 'DLC_resnet_50_tracecondiMay20shuffle1_1030000.csv'];
csvFile = fullfile(videoPath, csvFileName);

v = VideoReader(videoFile);
[audioData, audioFs] = audioread(audioFile);
coordData = readmatrix(csvFile);

%% Process Audio to Find Significant Events

numberOfFrames = v.NumberOfFrames;

aud = audioData;
Fs = audioFs;
% Take the absolute value of the audio signal and compute the mean to check if it exceeds a certain threshold
threshold = 0.02; % Set threshold
audio_abs = abs(aud); % Absolute value of audio signal
audio_mean = mean(audio_abs, 2); % Compute mean value per channel

% Find audio samples that exceed the threshold
loud_samples = find(audio_mean > threshold);

% Compute frame rate
frameRate = v.FrameRate; % Frame rate of the video

% Compute frame numbers corresponding to samples that exceed the threshold
loud_frames = ceil(loud_samples * frameRate / Fs);

% Remove duplicates
loud_frames_unique = unique(loud_frames);

% Initialize variables for segment detection
ndifferent = 20;
cuestartframe = [];

% Find frames where loud audio events start
for i = 2:(length(loud_frames_unique) - ndifferent + 1)
    % Check if the difference between consecutive frames exceeds the threshold
    currentFrameDiff = loud_frames_unique(i) - loud_frames_unique(i - 1);

    if currentFrameDiff > ndifferent
        cuestartframe = [cuestartframe; loud_frames_unique(i)];
    end
end

% Remove frames that do not meet criteria
skip_frames = [];
for i = 1:size(cuestartframe, 1)
    loud_index = find(loud_frames_unique == cuestartframe(i));
    if loud_frames_unique(loud_index) + ndifferent * 5 < loud_frames_unique(loud_index + 5)
        skip_frames = [skip_frames; i];
    end
end
cuestartframe(skip_frames) = [];

% Validate the number of detected segments
expectedSegments = 7;
if size(cuestartframe, 1) ~= expectedSegments
    error('Expected exactly %d segments, found %d. Stopping execution.', expectedSegments, size(cuestartframe, 1));
end

%% Extract Video Segments and Initialize Data

frameData = cell(5, 1);
DLC_temp = cell(5, 1);
for i = 1:5
    frameIndex = cuestartframe(i);  % Starting frame index
    startTime = frameIndex / v.FrameRate;  % Convert to start time in seconds
    startTime = startTime + 30;  % 30 seconds after the start time
    endTime = startTime + 10;    % End time is 10 seconds after the start time

    startFrame = ceil(startTime * v.FrameRate);
    endFrame = ceil(endTime * v.FrameRate);
    frameData{i} = read(v, [startFrame endFrame]);  % Save frame data
    DLC_temp{i} = calculate_center_data(coordData(startFrame:endFrame, :), 0.8);
end

% Initialize coordinate data for each frame
DLC_coord = cell(5, 151);
for i = 1:5
    for j = 1:151
        DLC_coord{i, j} = DLC_temp{i}(j, :);
    end
end

%% Create and Initialize GUI for Frame Annotation

% Create figure window with custom callbacks
hFig = figure('Name', 'Frame Editor', 'NumberTitle', 'off', 'KeyPressFcn', @keypress, ...
    'WindowButtonDownFcn', @mouseClick, 'CloseRequestFcn', @closeFig);
handles = guihandles(hFig);
handles.hFig = hFig;  % Add figure handle to handles structure
handles.v = v;
handles.frameData = frameData;
handles.currentSegment = 1;
handles.currentFrame = 1;
handles.totalFrames = size(frameData{1}, 4); % Total number of frames
handles.pointPositions = DLC_coord; % Array to store point positions
guidata(hFig, handles);
uiwait(hFig); % Pause execution and wait for GUI to close

% Save annotated points to MAT file
headname = [videoFileName(1:end-3) '_headpoint.mat'];
save(headname, "globalPointPositions");

%% Nested Functions for GUI Callbacks

% Function to extract and display the current frame
function extractAndShowFrame(handles)
    % Optimize image display by updating CData only
    if ~isfield(handles, 'imageHandle')
        handles.imageHandle = imshow(handles.frameData{handles.currentSegment}(:, :, :, handles.currentFrame));
        hold on;
    else
        set(handles.imageHandle, 'CData', handles.frameData{handles.currentSegment}(:, :, :, handles.currentFrame));
    end

    % Update text and point annotations
    if ~isfield(handles, 'textHandle')
        handles.textHandle = text(20, 20, '', 'Color', 'yellow', 'FontSize', 12, 'FontWeight', 'bold');
    end
    set(handles.textHandle, 'String', sprintf('Segment: %d, Frame: %d', handles.currentSegment, handles.currentFrame));

    if ~isfield(handles, 'pointHandle')
        handles.pointHandle = plot(0, 0, 'ro');
    end
    pos = handles.pointPositions{handles.currentSegment, handles.currentFrame};
    if ~isempty(pos)
        set(handles.pointHandle, 'XData', pos(1), 'YData', pos(2), 'Visible', 'on');
    else
        set(handles.pointHandle, 'Visible', 'off');
    end

    guidata(handles.hFig, handles);
end

% Callback function for key press events
function keypress(src, event)
    handles = guidata(src);
    switch event.Key
        case 'leftarrow'
            % Move to the previous frame
            if handles.currentFrame > 1
                handles.currentFrame = handles.currentFrame - 1;
            elseif handles.currentSegment > 1
                % If at the first frame, move to the last frame of the previous segment
                handles.currentSegment = handles.currentSegment - 1;
                handles.totalFrames = size(handles.frameData{handles.currentSegment}, 4);
                handles.currentFrame = handles.totalFrames;
            else
                % If at the first segment's first frame, loop to the last segment's last frame
                handles.currentSegment = length(handles.frameData);
                handles.totalFrames = size(handles.frameData{handles.currentSegment}, 4);
                handles.currentFrame = handles.totalFrames;
            end
        case 'rightarrow'
            % Move to the next frame
            if handles.currentFrame < handles.totalFrames
                handles.currentFrame = handles.currentFrame + 1;
            elseif handles.currentSegment < length(handles.frameData)
                % If at the last frame, move to the first frame of the next segment
                handles.currentSegment = handles.currentSegment + 1;
                handles.currentFrame = 1;
                handles.totalFrames = size(handles.frameData{handles.currentSegment}, 4);
            else
                % If at the last segment's last frame, loop to the first segment's first frame
                handles.currentSegment = 1;
                handles.currentFrame = 1;
            end
    end
    guidata(src, handles);
    extractAndShowFrame(handles);  % Update the display
end

% Function to check and jump to the next unmarked frame
function checkAndJumpToEmptyFrame(handles, src)
    % Check if all frames have been marked
    if all(~cellfun(@isempty, handles.pointPositions(handles.currentSegment, :)))
        disp('All frames in the current segment have been marked.');
    else
        % Find the next unmarked frame
        emptyFrames = find(cellfun(@isempty, handles.pointPositions(handles.currentSegment, :)));
        if ~isempty(emptyFrames) && emptyFrames(1) ~= handles.currentFrame
            handles.currentFrame = emptyFrames(1);  % Move to the first unmarked frame
            guidata(src, handles);
            extractAndShowFrame(handles);
        end
    end
end

% Callback function for mouse click events
function mouseClick(src, ~)
    handles = guidata(src);
    point = get(gca, 'CurrentPoint'); % Get the location of the click
    handles.pointPositions{handles.currentSegment, handles.currentFrame} = point(1, 1:2); % Store coordinates
    guidata(src, handles);
    extractAndShowFrame(handles);

    % Logic to navigate to unmarked frames
    if all(~cellfun(@isempty, handles.pointPositions(handles.currentSegment, :)))  % Check all frames in current segment
        disp('All points have been marked. Review or save your data.');
    else
        % Automatically move to the next unmarked frame
        emptyFrames = find(cellfun(@isempty, handles.pointPositions(handles.currentSegment, :)));
        if ~isempty(emptyFrames)
            handles.currentFrame = emptyFrames(1);
            guidata(src, handles);
            extractAndShowFrame(handles);
        end
    end
end

% Callback function when the figure window is closed
function closeFig(src, ~)
    % Get data handles from the figure
    handles = guidata(src);

    % Save point positions to a global variable
    global globalPointPositions;
    globalPointPositions = handles.pointPositions;

    % Close the figure window
    delete(src);
end
