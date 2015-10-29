% Bar-code parser
% Author: Osama Attia
% Descreption:
%      A simple barcode parser. This project done for
%      computer preception course at Iowa State University

% Clean environemnt
clear all; clc; close all;

% Set debug mode to 1 to show figures of the intermediate processing
DEBUG = 0;

% Filename and crop settings
files = ['samples/barcode_1.jpg'; 'samples/barcode_2.jpg'];
crop_setting = [0.1 0.6; 0.1 0.6]; % Heuristic

for filenum = 1:size(files)
    % Load image settings
    filename = files(filenum,:);
    f_start = crop_setting(filenum, 1);
    f_height = crop_setting(filenum, 2);

    % Load image
    a = imread(filename);
    % Display the image
    if DEBUG == 1
        subplot(2,2,1), imshow(a);
        title '1. Original image';
    end

    % Invert image
    inv_img = ~im2bw(a);
    % Erode image
    inv_img = imerode(inv_img, [1; 1; 1]);
    % Dilate image
    inv_img = imdilate(inv_img, [1; 1; 1]);
    % Display image after inversion/erosion/dilation
    if DEBUG == 1
        subplot(2,2,2), imshow(inv_img);
        title '2. Inverion/erosion/dilation';
    end

    % Get the an interesting part in the image
    crop_start = floor(size(inv_img) * f_start);           % Start crop at this percentage
    crop_height = floor(size(inv_img) * f_height);    % Crop this percentage of the image
    barcode = inv_img(crop_start:crop_start+crop_height, :);

    % Display the barcode part after crop
    if DEBUG == 1
        subplot(2,2,[3 4]), imshow(barcode);
        title '3. Crop the interesting part';
    end

    % Process the interesting part row by row
    bars = zeros(1,95);
    for i = 1:size(barcode, 1)
        % Get row
        row = barcode(i,:);
        % Trim row from leading and trailing zeros
        trim_row = row(find(row, 1, 'first'):find(row, 1, 'last'));

        % Calculate segment length
        length = size(trim_row, 2);
        step = length / 95;
        if step < 1
            disp('Error, very small image');
            return;
        end

        % Interpolate the value in each segment and add it to the bars vector
        for k = 1:95
            bars(k) = bars(k) + interp1(1:size(trim_row, 2), double(trim_row), (k-1)*step+step/2, 'NEAREST');
        end
    end

    % Normalize bars
    bars = round(bars ./ size(barcode, 1));
    % Display bars
    if DEBUG == 1
        figure; subplot(2,1,1), stem(bars);
        set(gca,'YMinorTick','on','YGrid','on','YMinorGrid','on','YLim',[0 2],'XLim',[0 96]);
        title '5. Averaging over rows';
    end

    % Display the last trimmed row -- Just for demonstration purpose
    if DEBUG == 1
        subplot(2,1,2), plot(trim_row);
        set(gca,'YMinorTick','on','YGrid','on','YMinorGrid','on','YLim',[0 2],'XLim',[0 size(trim_row, 2)+1]);
        title '4. Sample trimmed row';
    end

    % Segment the barcode
    bars_value = zeros(1,48);
    the_start = bars(1:3);
    the_end = bars(93:95);
    the_middle = bars(46:50);

    % Convert left side of the bar to values
    k = 4; search_val = 1; c = 1;
    while (k <= 45)
        try
            m = find(bars(k:45) == search_val, 1, 'first');
            bars_value(c) = m-1;
        catch
            if all(bars(k:45))
                bars_value(c) = 46-k;
            end
        end

        search_val = abs(1 - search_val);
        k = k + m - 1;
        c = c+1;
    end

    % Convert right side of the bar to values
    k = 51; search_val = 0;
    while (k <= 95)
        try
            m = find(bars(k:95) == search_val, 1, 'first');
            bars_value(c) = m-1;
        catch
            if all(bars(k:95))
                bars_value(c) = 96-k;
            end
        end

        search_val = abs(1 - search_val);
        k = k + m - 1;
        c = c+1;
    end

    the_left = bars(4:45);
    the_right = bars(51:92);


    % Check start, middle, end
    if ~isequal(the_start, [1 0 1])
        disp('Incorrect start code!!');
    end
    if ~isequal(the_middle, [0 1 0 1 0])
        disp('Incorrect end code!!');
    end
    if ~isequal(the_end, [1 0 1])
        disp('Incorrect end code!!');
    end

    % Init results
    result = zeros(1, 12);

    % Decoding table - could be found online
    table = [3 2 1 1;... % 0
             2 2 2 1;... % 1
             2 1 2 2;... % 2
             1 4 1 1;... % 3
             1 1 3 2;... % 4
             1 2 3 1;... % 5
             1 1 1 4;... % 6
             1 3 1 2;... % 7
             1 2 1 3;... % 8
             3 1 1 2];   % 9

    % Decode the barcode values
    for i = 0:11
        try
            result(i+1) = find(ismember(table, bars_value(i*4+1:i*4+4), 'rows') == 1) - 1;
        catch
            disp(['Error: could not decode digit ' num2str(i+1)]);

            % Try to find the number with minimum distance
            D = zeros(1, 10);
            for k = 1:10
                D(k) = sum((table(k,:) - bars_value(i*4+1:i*4+4)) .^ 2);
            end
            [val, ind] = max(D);
            result(i+1) = ind - 1;
        end
    end

    % Print result
    number = num2str(result, '%d');
    disp(['Result: ' number(1) ' ' number(2:6) ' ' number(7:11) ' ' number(12)]);

    % Check the results using parity check
    parity = result(1) + result(3) + result(5) + result(7) + result(9) + result(11);
    parity = parity * 3;
    parity = parity + result(2) + result(4) + result(6) + result(8) + result(10);
    parity = 10 - mod(parity, 10);
    if parity == 10
        parity = 0;
    end
    if (parity == result(12))
        disp('Barcode found is correct!')
        figure; imshow(a);
        title(['\color{blue}' number(1), ' ', number(2:6), ' ', number(7:11), ' ', number(12), ' - Correct'], 'FontSize', 16);
    else
        disp('Barcode found is NOT correct!')
        figure; imshow(a);
        title(['\color{red}' number(1), ' ', number(2:6), ' ', number(7:11), ' ', number(12), ' - Wrong'], 'FontSize', 16);
    end
    
end
