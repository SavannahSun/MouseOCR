% Input
input_file = 'test_OCR-R.txt'; 
output_file_raw = 'test_data_matlab.csv'; 
output_file_extracted = 'extracted_data_matlab.csv'; 


opts = detectImportOptions(input_file, 'Delimiter', ' '); 
data = readtable(input_file, opts);


writetable(data, output_file_raw);
disp(['New file has been saved: ', output_file_raw]);

%%
columns_to_extract = {
    'LeftFrameNumber', 'LeftSeconds', 'LeftPupilX', 'LeftPupilY', ...
    'LeftPupilAngle', 'LeftTorsion', ...
    'RightFrameNumber', 'RightSeconds', 'RightPupilX', 'RightPupilY', ...
    'RightPupilAngle', 'RightTorsion'
};

extracted_data = data(:, columns_to_extract);

% % Add a newcolumn
% extracted_data.RealRollAngle = zeros(height(extracted_data), 1);
% 
% for i = 1:height(extracted_data)
%     if extracted_data.LeftSeconds(i) >= 128.22 && extracted_data.LeftSeconds(i) < 251.3
%         extracted_data.RealRollAngle(i) = -10;
%     elseif extracted_data.LeftSeconds(i) >= 256.04 && extracted_data.LeftSeconds(i) < 369.51
%         extracted_data.RealRollAngle(i) = 10;
%     elseif extracted_data.LeftSeconds(i) >= 375.8 && extracted_data.LeftSeconds(i) < 497.73
%         extracted_data.RealRollAngle(i) = -20;
%     elseif extracted_data.LeftSeconds(i) >= 512.47 && extracted_data.LeftSeconds(i) < 635.83
%         extracted_data.RealRollAngle(i) = 20;
%     elseif extracted_data.LeftSeconds(i) >= 646.89 && extracted_data.LeftSeconds(i) < 808.58
%         extracted_data.RealRollAngle(i) = -30;
%     elseif extracted_data.LeftSeconds(i) >= 816.23 && extracted_data.LeftSeconds(i) < 943.5
%         extracted_data.RealRollAngle(i) = 30;
%     else
%         extracted_data.RealRollAngle(i) = 0;
%     end
% end

writetable(extracted_data, output_file_extracted);
disp(['Extract the important columns: ', output_file_extracted]);