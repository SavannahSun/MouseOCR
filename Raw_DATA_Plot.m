clear all
close all
clc


%% Raw plot
input_file = 'extracted_data_matlab.csv'; 
data = readtable(input_file); 

x_axis = data.LeftSeconds;
y_axes = {'LeftPupilX', 'LeftPupilY'};
Torsion = (data.LeftTorsion + data.RightTorsion)/2; 

figure(1);
for i = 1:length(y_axes)
    subplot(3, 1, i); 
    plot(x_axis, data.(y_axes{i}), 'DisplayName', y_axes{i}); 
    set(gca,"FontSize",20)
%     ylim(y_range);
    title([y_axes{i} ' vs LeftSeconds'], 'FontSize', 32); 
    ylabel(y_axes{i}, 'FontSize', 32); 
%     legend show; 
    grid on; 
end
subplot(3, 1, 3); 
plot(x_axis, Torsion, 'DisplayName', 'Torsion', 'Color', 'r'); 
set(gca,"FontSize",20)
title('Torsion vs Seconds', 'FontSize', 32); 
ylabel('Torsion', 'FontSize', 32);  
grid on; 

xlabel('Seconds', 'FontSize', 32);
%% 
x_position = data.LeftPupilX; 
y_position = data.LeftPupilY;

% Claculate the diff
torsion_diff = abs([0; diff(Torsion)]); 
x_diff = abs([0; diff(x_position)]);
y_diff = abs([0; diff(y_position)]);

% Threshold
torsion_threshold = 2; 
position_threshold = 2;

% outlier
invalid_idx = (torsion_diff > torsion_threshold) | ...
              (x_diff > position_threshold) | ...
              (y_diff > position_threshold);

% Remove outliers and interpolate
torsion_cleaned = Torsion;
torsion_cleaned(invalid_idx) = NaN; % Mark the outlier as NaN
torsion_cleaned = fillmissing(torsion_cleaned, 'linear'); % linear interpolation

% Filter parameter
fs = 3; 
cutoff = 1/120; % 90 second change frequency
order = 4; 

% Butterworth
[b, a] = butter(order, cutoff / (fs / 2), 'low');

% Filter the Torsion data after cleaning
torsion_smoothed = filtfilt(b, a, torsion_cleaned);

%%
figure(2);
t = data.LeftSeconds; 
RealRollAngle = assign_values(x_axis);

% Origin
subplot(3, 1, 1);
plot(t, Torsion, 'b');
title('Original Torsion Signal',fontsize=20);
xlabel('Time (s)');
ylabel('Torsion (degrees)');
xlim([22,max(t)]);
ylim([-20,20]);
grid on;

% Cleaned
subplot(3, 1, 2);
plot(t, torsion_cleaned, 'g');
title('Torsion Signal After Outlier Removal',fontsize=20);
xlabel('Time (s)');
ylabel('Torsion (degrees)');
xlim([22,max(t)]);
ylim([-20,20]);
grid on;

% Smooth
subplot(3, 1, 3);
plot(t, torsion_smoothed, 'r','LineWidth',2);
hold on
plot(t, -1 * RealRollAngle,'black')
hold off
title('Torsion Signal After Smoothing',fontsize=20);
xlabel('Time (s)');
ylabel('Torsion (degrees)');
xlim([22,max(t)]);
ylim([-20,20]);
grid on;
%%
figure(3);

plot(t, Torsion, 'g'); hold on
plot(t, torsion_cleaned, 'b'); hold on
plot(t, torsion_smoothed, 'r','LineWidth',2); hold on
plot(t, -1 * RealRollAngle,'black','LineStyle',':', 'LineWidth',2); hold on
set(gca,"FontSize",20)
xlabel('Time (s)', 'FontSize', 32);
ylabel('Torsion (degrees)', 'FontSize', 32);
xlim([22,max(t)]);
ylim([-35,35]);
title({'Torsion Signal Processing'}, 'FontSize', 32);
legend({'Original', 'Cleaned','Smoothed','Neg Roll Angel'}, 'FontSize', 32)
grid on
hold off


%%
figure(4);
% t = data.LeftSeconds; 
y_sim = -0.5 * RealRollAngle;
% plot(t, Torsion, 'b');
% hold on
% plot(t, torsion_cleaned, 'r');
% hold on
plot(t, torsion_smoothed, 'r', 'LineWidth', 2);hold on
plot(t, y_sim, 'b--', 'LineWidth', 2); hold on
set(gca,"FontSize",20)
xlabel({'Time (s)'}, 'FontSize', 20);
ylabel({'Torsion (degrees)'}, 'FontSize', 20);
% xlim([min(t), max(t)])
% ylim([-35, 35])
title({'Torsion Signal'}, 'FontSize', 22);
ylim([-20,20]);
xlim([22,max(t)]);
grid on;
legend({'Signal After Smooth','Neg Half Roll Angle'}, 'FontSize', 20)
hold off
%%
% Run this after 'Raw_DATA_Plot.m'
% Detect symbol change points
sign_changes = [true; diff(sign(torsion_smoothed)) ~= 0]; 
segments = find(sign_changes); 

% Initializes the result store
avg_values = zeros(length(segments) - 1, 1); 
start_indices = segments(1:end-1); % Segment beginning
end_indices = segments(2:end) - 1; % Segment end
mid_indices = floor((start_indices + end_indices) / 2); % Segment mid

% Calculate avg
fprintf('Seg\tStartTime\tEndTime\tAvg\n');
for i = 1:length(avg_values)
    avg_values(i) = mean(torsion_smoothed(start_indices(i):end_indices(i)));
    fprintf('%d\t%.2f\t%.2f\t%.2f\n', i, t(start_indices(i)), t(end_indices(i)), avg_values(i));
end

avg_curve = zeros(size(torsion_smoothed));
for i = 1:length(avg_values)
    avg_curve(start_indices(i):end_indices(i)) = avg_values(i);
end

% Plot torsion_smoothed and avg_curve
figure(5);
hold on;
plot(t, torsion_smoothed, 'b', 'DisplayName', 'Torsion Smoothed', 'LineWidth', 1.5);
plot(t, avg_curve, 'r--', 'DisplayName', 'Stage Average', 'LineWidth', 1.5);
set(gca,"FontSize",20)
% Annotate the average value on the plot
for i = 1:length(avg_values)
    mid_time = t(mid_indices(i)); % Midpoint time
    avg_value = avg_values(i); % Average value
    text(mid_time, avg_value, sprintf('%.2f', avg_value), 'Color', 'k', ...
         'FontSize', 20, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

legend show;
title('Torsion Smoothed and Stage Average', 'FontSize', 20);
xlabel('Time (t)', 'FontSize', 20);
ylabel('Torsion', 'FontSize', 20);
ylim([-20,20]);
xlim([22,max(t)]);
grid on;
hold off;

%%

% t_drift_corrected = detrend(torsion_smoothed);
% 
% figure
% plot(t_drift_corrected)

%%
function y = assign_values(x_axis)
    % Input: x_axis - Time series (LeftSeconds)
    % Output: y - The sequence after the value is assigned according to the time period

    % Output: y - The sequence after the value is assigned according to the time period
    y = zeros(size(x_axis));

    y(x_axis >= 22 & x_axis < 60) = 0;       % 22 -- 60
    y(x_axis >= 60 & x_axis < 100) = 10;     % 60 -- 100
    y(x_axis >= 100 & x_axis < 138) = -10;   % 100 -- 138
    y(x_axis >= 138 & x_axis < 177) = 20;    % 138 -- 177
    y(x_axis >= 177 & x_axis < 211) = -20;   % 177 -- 211
    y(x_axis >= 211 & x_axis < 241) = 30;    % 121 -- 241
end

