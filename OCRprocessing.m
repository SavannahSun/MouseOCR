classdef OCRprocessing < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        MainTabGroup                    matlab.ui.container.TabGroup
        RawDataTab                      matlab.ui.container.Tab
        UIAxes3                         matlab.ui.control.UIAxes
        UIAxes2                         matlab.ui.control.UIAxes
        UIAxes                          matlab.ui.control.UIAxes
        ProcessedTab                    matlab.ui.container.Tab
        MeanValueLabel                  matlab.ui.control.Label
        SignalShowPanel                 matlab.ui.container.Panel
        FilteredSignalCheckBox          matlab.ui.control.CheckBox
        CleanedSignalCheckBox           matlab.ui.control.CheckBox
        OriginalSignalCheckBox          matlab.ui.control.CheckBox
        NoiseFilterPanel                matlab.ui.container.Panel
        ApplyFilterButton_2             matlab.ui.control.Button
        PositionThresholdEditField      matlab.ui.control.NumericEditField
        PositionThresholdEditFieldLabel  matlab.ui.control.Label
        TorsionThresholdEditField       matlab.ui.control.NumericEditField
        TorsionThresholdEditFieldLabel  matlab.ui.control.Label
        ButterworthFilterPanel          matlab.ui.container.Panel
        ApplyFilterButton               matlab.ui.control.Button
        OrderEditField                  matlab.ui.control.NumericEditField
        OrderEditFieldLabel             matlab.ui.control.Label
        cutoffEditField                 matlab.ui.control.NumericEditField
        cutoffEditFieldLabel            matlab.ui.control.Label
        fsEditField                     matlab.ui.control.NumericEditField
        fsEditFieldLabel                matlab.ui.control.Label
        CalculateMeanButto              matlab.ui.control.Button
        UIAxesProcessed                 matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        data
        x_axis
        torsion
        cleaned_torsion 
        filtered_torsion 
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            try
                % Let the user select the '.txt 'fi
                [file, path] = uigetfile('*.txt', 'Select the.txt file you want to convert');
        
                % If the user deselects, it terminates
                if isequal(file, 0)
                    disp('The user deselects, terminating the processing.');
                    return;
                end
                
                % Target file path
                input_file = fullfile(path, file);
                extracted_file = fullfile(path, 'extracted_data_matlab.csv');
                
                % Read the '.txt' file
                disp(['Read the file: ', input_file]);
                opts = detectImportOptions(input_file, 'Delimiter', ' ');
                
                % Check if the file exists
                if ~isfile(input_file)
                    disp(['Error: The file does not exist ', input_file]);
                    return;
                end
               
                app.data = readtable(input_file, opts);
                
                % Select the columns to extract
                columns_to_extract = {
                    'LeftFrameNumber', 'LeftSeconds', 'LeftPupilX', 'LeftPupilY', ...
                    'LeftPupilAngle', 'LeftTorsion', ...
                    'RightFrameNumber', 'RightSeconds', 'RightPupilX', 'RightPupilY', ...
                    'RightPupilAngle', 'RightTorsion'
                };
                
                % Ensure that the data contains all required columns
                valid_columns = intersect(columns_to_extract, app.data.Properties.VariableNames);
                
                % If there are no valid columns, abort
                if isempty(valid_columns)
                    disp('Error: No valid columns found in the data file.');
                    return;
                end
                
                extracted_data = app.data(:, valid_columns);
                
                % Save the converted.csv file
                writetable(extracted_data, extracted_file);
                disp(['Conversion complete, saved: ', extracted_file]);
                
                % Read the converted '.csv 'file
                app.data = extracted_data;
                
                % Ensure that 'LeftSeconds' exists
                if ~ismember('LeftSeconds', app.data.Properties.VariableNames)
                    disp('Error: LeftSeconds column not found in data.');
                    return;
                end
                
                % Ensure the data is not empty
                if isempty(app.data.LeftSeconds)
                    disp('Error: No time data available in LeftSeconds.');
                    return;
                end
                
                app.x_axis = app.data.LeftSeconds;
                
                % Ensure 'Torsion' calculation is valid
                if ismember('LeftTorsion', app.data.Properties.VariableNames) && ...
                   ismember('RightTorsion', app.data.Properties.VariableNames)
                    app.torsion = (app.data.LeftTorsion + app.data.RightTorsion) / 2;
                else
                    disp('Error: Missing torsion data.');
                    return;
                end
                
                app.torsion = (app.data.LeftTorsion + app.data.RightTorsion) / 2;
                
                % Plot the Row Plot
                plot(app.UIAxes, app.x_axis, app.data.LeftPupilX);
                title(app.UIAxes, 'X Movement (mm)');
                xlabel(app.UIAxes, 'LeftSeconds'); ylabel(app.UIAxes, 'X');
                
                plot(app.UIAxes2, app.x_axis, app.data.LeftPupilY);
                title(app.UIAxes2, 'Y Movement (mm)');
                xlabel(app.UIAxes2, 'LeftSeconds'); ylabel(app.UIAxes2, 'Y');
                
                plot(app.UIAxes3, app.x_axis, app.torsion);
                title(app.UIAxes3, 'Torsion (deg)');
                xlabel(app.UIAxes3, 'LeftSeconds'); ylabel(app.UIAxes3, 'Torsion');
                
            catch ME
                disp(['Data loading failure:', ME.message])
            end
            
        end

        % Button pushed function: ApplyFilterButton_2
        function ApplyFilterButton_2Pushed(app, event)
            try
                % Make sure the data is loaded
                if isempty(app.data)
                    disp('Error: No data loaded. Please select a file first.');
                    return;
                end
                % Gets the Threshold value entered by the user
                torsion_threshold = app.TorsionThresholdEditField.Value;
                position_threshold = app.PositionThresholdEditField.Value;
                disp(['Using Torsion Threshold: ', num2str(torsion_threshold)]);
                disp(['Using Position Threshold: ', num2str(position_threshold)]);

                % Calculate the diff of the signal
                torsion_diff = abs([0; diff(app.torsion)]);
                x_diff = abs([0; diff(app.data.LeftPupilX)]);
                y_diff = abs([0; diff(app.data.LeftPupilY)]);
                
                % Identify outliers (beyond threshold）
                invalid_idx = (torsion_diff > torsion_threshold) | ...
                              (x_diff > position_threshold) | ...
                              (y_diff > position_threshold);

                % Processing data: outliers are replaced with NaN and linear interpolation is performed
                app.cleaned_torsion = app.torsion;
                app.cleaned_torsion(invalid_idx) = NaN;
                app.cleaned_torsion = fillmissing(app.cleaned_torsion, 'linear');
                
                % Draw Cleaned signal in 'UIAxesProcessed'
                plot(app.UIAxesProcessed, app.x_axis, app.cleaned_torsion, 'g', 'LineWidth', 1.5);
                title(app.UIAxesProcessed, 'Cleaned Torsion Signal');
                xlabel(app.UIAxesProcessed, 'LeftSeconds');
                ylabel(app.UIAxesProcessed, 'Torsion (deg)');
                grid(app.UIAxesProcessed, 'on');

                disp('Cleaned data plotted successfully.');

                
            catch ME
                disp(['Error in cleanDataAndPlot: ', ME.message]);
                
            end
        end

        % Button pushed function: ApplyFilterButton
        function ApplyFilterButtonPushed(app, event)
            try
                % Make sure the Cleaned data is generated
                if isempty(app.cleaned_torsion)
                    disp('Error: No cleaned data available. Please run "Clean Data" first.');
                    return;
                end
                
                % Gets filtering parameters for user input
                fs = app.fsEditField.Value;
                cutoff = app.cutoffEditField.Value;
                order = app.OrderEditField.Value;
                
                disp(['Applying Butterworth Filter with fs=', num2str(fs), ...
                     ', cutoff=', num2str(cutoff), ', order=', num2str(order)]);
                
                % Design Butterworth filter
                [b, a] = butter(order, cutoff / (fs / 2), 'low');
                
                % The Cleaned signal is filtered
                app.filtered_torsion = filtfilt(b, a, app.cleaned_torsion);
                
                % Draws Filtered signals in 'UIAxesProcessed'
                plot(app.UIAxesProcessed, app.x_axis, app.filtered_torsion, 'r', 'LineWidth', 1.5);
                title(app.UIAxesProcessed, 'Filtered Torsion Signal');
                xlabel(app.UIAxesProcessed, 'LeftSeconds');
                ylabel(app.UIAxesProcessed, 'Torsion (deg)');
                grid(app.UIAxesProcessed, 'on');
                
                disp('Filtered data plotted successfully.');
                
                
            catch ME
                disp(['Error in applyButterworthFilter: ', ME.message]);     
                
            end
        end

        % Callback function
        function updatePlot(app, event)
            try
                % Make sure the data is loaded
                if isempty(app.data)
                    disp('Error: No data loaded.');
                    return;
                end
                
                % Clear current image
                hold(app.UIAxesProcessed, 'off');
                
                % Select the signal to display according to the CheckBox
                legendEntries = {}; % Memory legend
                if app.OriginalSignalCheckBox.Value
                    plot(app.UIAxesProcessed, app.x_axis, app.torsion, 'b', 'LineWidth', 1);
                    hold(app.UIAxesProcessed, 'on');
                    legendEntries{end+1} = 'Original Signal';
                end
        
                if app.CleanedSignalCheckBox.Value
                    plot(app.UIAxesProcessed, app.x_axis, app.cleaned_torsion, 'g', 'LineWidth', 1);
                    hold(app.UIAxesProcessed, 'on');
                    legendEntries{end+1} = 'Cleaned Signal';
                end
        
                if app.FilteredSignalCheckBox.Value
                    plot(app.UIAxesProcessed, app.x_axis, app.filtered_torsion, 'r', 'LineWidth', 1);
                    hold(app.UIAxesProcessed, 'on');
                    legendEntries{end+1} = 'Filtered Signal';
                end
                
                % Set legend
                if ~isempty(legendEntries)
                    legend(app.UIAxesProcessed, legendEntries, 'Location', 'best');
                end
        
                % Set axis label
                title(app.UIAxesProcessed, 'Torsion Signal Comparison');
                xlabel(app.UIAxesProcessed, 'LeftSeconds');
                ylabel(app.UIAxesProcessed, 'Torsion (deg)');
                grid(app.UIAxesProcessed, 'on');

                disp('Updated plot based on user selection.');

                
            catch ME
                disp(['Error in updatePlot: ', ME.message]);
                
            end
        end

        % Value changed function: OriginalSignalCheckBox
        function OriginalSignalCheckBoxValueChanged(app, event)
            updatePlot(app, event);
        end

        % Value changed function: CleanedSignalCheckBox
        function CleanedSignalCheckBoxValueChanged(app, event)
            updatePlot(app, event);
        end

        % Value changed function: FilteredSignalCheckBox
        function FilteredSignalCheckBoxValueChanged(app, event)
            updatePlot(app, event);
        end

        % Button pushed function: CalculateMeanButto
        function CalculateMeanButtoButtonPushed(app, event)
            try
                % Make sure there's data in UIAxesProcessed
                if isempty(app.x_axis) || isempty(app.torsion)
                    disp('Error: No data available.');
                    return;
                end
        
                % Gets the currently selected signal data
                if app.FilteredSignalCheckBox.Value
                    y_data = app.filtered_torsion;
                    signal_label = 'Filtered Signal';
                elseif app.CleanedSignalCheckBox.Value
                    y_data = app.cleaned_torsion;
                    signal_label = 'Cleaned Signal';
                elseif app.OriginalSignalCheckBox.Value
                    y_data = app.torsion;
                    signal_label = 'Original Signal';
                else
                    disp('Error: No signal selected.');
                    return;
                end
        
                % Open a new Figure and draw the selected signal
                fig = figure('Name', 'Select Two Points', 'NumberTitle', 'off');
                ax = axes(fig); 
                plot(ax, app.x_axis, y_data, 'b', 'LineWidth', 1.5);
                title(ax, ['Select Two Points on ' signal_label]);
                ylim(ax, [-30, 30]); 
                xlabel(ax, 'LeftSeconds');
                ylabel(ax, 'Torsion');
                grid(ax, 'on');

        
                % Prompts the user to select two points
                disp('Please click on two points on the new figure.');
        
                % Ask the user to select two points in the new Figure
                [x_selected, ~] = ginput(2);  
        
                % Find the nearest X-axis index
                [~, idx1] = min(abs(app.x_axis - x_selected(1)));
                [~, idx2] = min(abs(app.x_axis - x_selected(2)));
        
                % Make sure idx1 < idx2
                if idx1 > idx2
                    temp = idx1;
                    idx1 = idx2;
                    idx2 = temp;
                end
        
                % Calculates the average of all y values in the selected range
                mean_value = mean(y_data(idx1:idx2));
        
                % Mark the selected two points
                hold(ax, 'on');
                plot(ax, app.x_axis([idx1, idx2]), y_data([idx1, idx2]), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
                hold(ax, 'off');
        
                % Update MeanValueLabel in GUI
                app.MeanValueLabel.Text = ['Mean Value: ', num2str(mean_value, '%.3f')];
        
                disp(['Mean Value of selected range: ', num2str(mean_value, '%.3f')]);
                
                
                
            catch ME
                disp(['Error in CalculateMeanButtonPushed: ', ME.message]);
                
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'MATLAB App';

            % Create MainTabGroup
            app.MainTabGroup = uitabgroup(app.UIFigure);
            app.MainTabGroup.Position = [1 1 640 480];

            % Create RawDataTab
            app.RawDataTab = uitab(app.MainTabGroup);
            app.RawDataTab.Title = 'RawDataTab';

            % Create UIAxes
            app.UIAxes = uiaxes(app.RawDataTab);
            title(app.UIAxes, 'X Movement')
            xlabel(app.UIAxes, 'LeftSeconds')
            ylabel(app.UIAxes, 'X (mm)')
            app.UIAxes.FontSize = 12;
            app.UIAxes.Position = [29 312 582 129];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.RawDataTab);
            title(app.UIAxes2, 'Y Movement')
            xlabel(app.UIAxes2, 'LeftSeconds')
            ylabel(app.UIAxes2, 'Y (mm)')
            app.UIAxes2.Position = [29 175 582 138];

            % Create UIAxes3
            app.UIAxes3 = uiaxes(app.RawDataTab);
            title(app.UIAxes3, 'Torsion')
            xlabel(app.UIAxes3, 'LeftSeconds')
            ylabel(app.UIAxes3, 'Torsion (deg)')
            app.UIAxes3.Position = [29 31 582 145];

            % Create ProcessedTab
            app.ProcessedTab = uitab(app.MainTabGroup);
            app.ProcessedTab.Title = 'ProcessedTab';

            % Create UIAxesProcessed
            app.UIAxesProcessed = uiaxes(app.ProcessedTab);
            title(app.UIAxesProcessed, 'Signal Processing')
            xlabel(app.UIAxesProcessed, 'Time')
            ylabel(app.UIAxesProcessed, 'Torsion Angle (deg)')
            app.UIAxesProcessed.Position = [10 17 421 424];

            % Create CalculateMeanButto
            app.CalculateMeanButto = uibutton(app.ProcessedTab, 'push');
            app.CalculateMeanButto.ButtonPushedFcn = createCallbackFcn(app, @CalculateMeanButtoButtonPushed, true);
            app.CalculateMeanButto.Position = [445 41 66 22];
            app.CalculateMeanButto.Text = 'Calculate';

            % Create ButterworthFilterPanel
            app.ButterworthFilterPanel = uipanel(app.ProcessedTab);
            app.ButterworthFilterPanel.Title = 'ButterworthFilter';
            app.ButterworthFilterPanel.Position = [445 175 180 138];

            % Create fsEditFieldLabel
            app.fsEditFieldLabel = uilabel(app.ButterworthFilterPanel);
            app.fsEditFieldLabel.HorizontalAlignment = 'right';
            app.fsEditFieldLabel.Position = [14 94 25 22];
            app.fsEditFieldLabel.Text = 'fs';

            % Create fsEditField
            app.fsEditField = uieditfield(app.ButterworthFilterPanel, 'numeric');
            app.fsEditField.Position = [53 94 113 22];

            % Create cutoffEditFieldLabel
            app.cutoffEditFieldLabel = uilabel(app.ButterworthFilterPanel);
            app.cutoffEditFieldLabel.HorizontalAlignment = 'right';
            app.cutoffEditFieldLabel.Position = [11 62 36 22];
            app.cutoffEditFieldLabel.Text = 'cutoff';

            % Create cutoffEditField
            app.cutoffEditField = uieditfield(app.ButterworthFilterPanel, 'numeric');
            app.cutoffEditField.Position = [62 62 104 22];

            % Create OrderEditFieldLabel
            app.OrderEditFieldLabel = uilabel(app.ButterworthFilterPanel);
            app.OrderEditFieldLabel.HorizontalAlignment = 'right';
            app.OrderEditFieldLabel.Position = [11 33 36 22];
            app.OrderEditFieldLabel.Text = 'Order';

            % Create OrderEditField
            app.OrderEditField = uieditfield(app.ButterworthFilterPanel, 'numeric');
            app.OrderEditField.Position = [62 33 104 22];

            % Create ApplyFilterButton
            app.ApplyFilterButton = uibutton(app.ButterworthFilterPanel, 'push');
            app.ApplyFilterButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyFilterButtonPushed, true);
            app.ApplyFilterButton.Position = [14 3 152 22];
            app.ApplyFilterButton.Text = 'Apply Filter';

            % Create NoiseFilterPanel
            app.NoiseFilterPanel = uipanel(app.ProcessedTab);
            app.NoiseFilterPanel.Title = 'Noise Filter';
            app.NoiseFilterPanel.Position = [445 333 180 108];

            % Create TorsionThresholdEditFieldLabel
            app.TorsionThresholdEditFieldLabel = uilabel(app.NoiseFilterPanel);
            app.TorsionThresholdEditFieldLabel.HorizontalAlignment = 'right';
            app.TorsionThresholdEditFieldLabel.Position = [10 58 97 22];
            app.TorsionThresholdEditFieldLabel.Text = 'TorsionThreshold';

            % Create TorsionThresholdEditField
            app.TorsionThresholdEditField = uieditfield(app.NoiseFilterPanel, 'numeric');
            app.TorsionThresholdEditField.Position = [122 58 44 22];

            % Create PositionThresholdEditFieldLabel
            app.PositionThresholdEditFieldLabel = uilabel(app.NoiseFilterPanel);
            app.PositionThresholdEditFieldLabel.HorizontalAlignment = 'right';
            app.PositionThresholdEditFieldLabel.Position = [10 32 102 22];
            app.PositionThresholdEditFieldLabel.Text = 'PositionThreshold';

            % Create PositionThresholdEditField
            app.PositionThresholdEditField = uieditfield(app.NoiseFilterPanel, 'numeric');
            app.PositionThresholdEditField.Position = [126 32 40 22];

            % Create ApplyFilterButton_2
            app.ApplyFilterButton_2 = uibutton(app.NoiseFilterPanel, 'push');
            app.ApplyFilterButton_2.ButtonPushedFcn = createCallbackFcn(app, @ApplyFilterButton_2Pushed, true);
            app.ApplyFilterButton_2.Position = [14 6 152 22];
            app.ApplyFilterButton_2.Text = 'Apply Filter';

            % Create SignalShowPanel
            app.SignalShowPanel = uipanel(app.ProcessedTab);
            app.SignalShowPanel.Title = 'Signal Show';
            app.SignalShowPanel.Position = [445 81 180 86];

            % Create OriginalSignalCheckBox
            app.OriginalSignalCheckBox = uicheckbox(app.SignalShowPanel);
            app.OriginalSignalCheckBox.ValueChangedFcn = createCallbackFcn(app, @OriginalSignalCheckBoxValueChanged, true);
            app.OriginalSignalCheckBox.Text = 'Original Signal';
            app.OriginalSignalCheckBox.Position = [10 42 100 22];

            % Create CleanedSignalCheckBox
            app.CleanedSignalCheckBox = uicheckbox(app.SignalShowPanel);
            app.CleanedSignalCheckBox.ValueChangedFcn = createCallbackFcn(app, @CleanedSignalCheckBoxValueChanged, true);
            app.CleanedSignalCheckBox.Text = 'Cleaned Signal';
            app.CleanedSignalCheckBox.Position = [9 21 103 22];

            % Create FilteredSignalCheckBox
            app.FilteredSignalCheckBox = uicheckbox(app.SignalShowPanel);
            app.FilteredSignalCheckBox.ValueChangedFcn = createCallbackFcn(app, @FilteredSignalCheckBoxValueChanged, true);
            app.FilteredSignalCheckBox.Text = 'Filtered Signal';
            app.FilteredSignalCheckBox.Position = [9 0 98 22];

            % Create MeanValueLabel
            app.MeanValueLabel = uilabel(app.ProcessedTab);
            app.MeanValueLabel.Position = [445 17 180 22];
            app.MeanValueLabel.Text = 'Mean Value:';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = OCRprocessing

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end