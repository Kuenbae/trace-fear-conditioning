% MATLAB Script for Processing Head Point Data and Calculating Velocity
%
% This script processes multiple MAT files containing head point positions.
% It loads each file, extracts position data, interpolates missing values,
% calculates velocities between consecutive positions, and computes the mean velocity.
% Finally, it reshapes the velocity data for further analysis.
%
% Instructions:
% - Ensure that all MAT files matching the pattern 'L*tt2._headpoint.mat' are in the current directory.
% - The MAT files should contain a variable named 'globalPointPositions'.
% - Run the script to process the data and obtain the reshaped velocity vector.

clc
clear

% Get information about all MAT files matching the pattern 'L*tt2._headpoint.mat'
MyFolderInfo = dir('L*tt2._headpoint.mat');

% Extract filenames from the directory information
matfilename = cell(size(MyFolderInfo, 1), 1);
for i = 1:size(MyFolderInfo, 1)
    matfilename{i} = MyFolderInfo(i).name;
end

% Reorder filenames as needed (modify indices as per your requirements)
matfilename = matfilename([14 15 16 17 1:13]);

%% Main Processing Loop

% Initialize variables
numSegments = 5;  % Number of segments or trials
numFiles = size(matfilename, 1);  % Total number of files
delay_velocity = zeros(numSegments, numFiles);  % Matrix to store mean velocities

for i = 1:numFiles

    file = matfilename{i};
    load(file)  % Load the MAT file, which should contain 'globalPointPositions'

    % Check if 'globalPointPositions' exists
    if ~exist('globalPointPositions', 'var')
        error('The variable ''globalPointPositions'' was not found in %s.', file);
    end

    % Determine the number of frames based on the size of 'globalPointPositions'
    numFrames = size(globalPointPositions, 2);

    % Initialize velocity matrix for this file
    velocity = zeros(numFrames - 1, numSegments);

    for j = 1:numSegments  % Iterate over each segment

        % Initialize position matrix for x and y coordinates
        position = nan(numFrames, 2);

        for k = 1:numFrames  % Iterate over each frame

            % Extract x-coordinate
            if isempty(globalPointPositions{j, k})
                position(k, 1) = nan;
            else
                position(k, 1) = globalPointPositions{j, k}(1);
            end

            % Extract y-coordinate
            if isempty(globalPointPositions{j, k})
                position(k, 2) = nan;
            else
                position(k, 2) = globalPointPositions{j, k}(2);
            end

        end

        data = position;  % Assign position data to 'data' for processing

        % Check for NaN values and perform interpolation
        for coordIdx = 1:size(data, 2)  % For each coordinate (x and y)
            validIdx = ~isnan(data(:, coordIdx));  % Indices of valid data
            if sum(validIdx) > 1  % Need at least two valid points to interpolate
                data(:, coordIdx) = interp1(find(validIdx), data(validIdx, coordIdx), 1:numFrames, 'linear', 'extrap');
            else
                % If not enough valid data, fill with NaNs
                data(:, coordIdx) = nan(numFrames, 1);
            end
        end

        % Calculate velocity between consecutive positions
        for k = 1:numFrames - 1
            dx = data(k + 1, 1) - data(k, 1);  % Change in x
            dy = data(k + 1, 2) - data(k, 2);  % Change in y
            velocity(k, j) = sqrt(dx^2 + dy^2);  % Calculate speed using Euclidean distance
        end

    end

    % Compute mean velocity for each segment and store in 'delay_velocity'
    delay_velocity(1:numSegments, i) = mean(velocity, 1, 'omitnan')';

    % Clear variables for the next iteration
    clear globalPointPositions velocity data position

end

% Reshape 'delay_velocity' into a column vector for further analysis
reshaped_velocity = reshape(delay_velocity, [], 1);

% Display the reshaped velocity vector
disp('Reshaped Velocity Vector:');
disp(reshaped_velocity);
