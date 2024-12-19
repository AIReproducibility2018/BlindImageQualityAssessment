% Arguments
src_path = "C:\Users\oddca\Documents\Masteroppgave\R1\BlindImageQualityAssesment\Data\databaserelease2\";
folders = ["jp2k" "jpeg" "wn" "gblur" "fastfading"];
tid_data_folder = "..\Data\tid2008\distorted_images\";
tid_dataset_file = "..\Data\tid2008\mos_with_names.txt";
output_folder = "..\Results\";
random_seed = 1;

% Set random seed
rng(random_seed);

srocc = calculateTidSubsetSrocc(tid_data_folder, tid_dataset_file, output_folder, live_b, live_gama, live_mu, live_sigma_inv);

function testLive(src_path, folders)
    % For each folder of test images
    for i=1:5
        predictions = [];

        folder = char(strcat(src_path, folders(i)));
        folderInfo = dir(folder);

        % For all images in folder
        for j=1:length(folderInfo)

            imageName = folderInfo(j).name;
            if (endsWith(imageName, '.bmp'))

                % Read image
                imagePath = char(strcat(src_path, folders(i), "\", imageName))
                img = imread(imagePath);

                % Get features
                features = bliinds2_feature_extraction(img);
                scale_1 = transpose(features(:,1));
                scale_2 = transpose(features(:,2));
                scale_3 = transpose(features(:,3));
                collected = cat(2, scale_1, cat(2, scale_2, scale_3));

                % Compute predicted DMOS 
                prediction = bliinds_prediction(collected)
                predictions = [predictions; prediction];
            end
        end

        % Generate matrix with two columns: predicted and actual
        results = transpose([transpose(predictions); dmos(1:227)])
        %save('results,mat', results);

        % Calculate Spearman's rho
        srocc = corr(results,'type','Spearman')
    end
end

function results = testTid(folder, b, gama, mu, sigma_inv)
    folderInfo = dir(char(folder));
    
    predictions = [];
    
    % For all images in folder
    for j=1:length(folderInfo)
        disp(j)
        imageName = folderInfo(j).name;
        if (endsWith(imageName, '.bmp'))

            % Read image
            imagePath = char(strcat(folder, imageName))
            img = imread(imagePath);

            % Get features
            features = bliinds2_feature_extraction(img);
            scale_1 = transpose(features(:,1));
            scale_2 = transpose(features(:,2));
            scale_3 = transpose(features(:,3));
            collected = cat(2, scale_1, cat(2, scale_2, scale_3));

            % Compute predicted DMOS 
            prediction = bliinds_prediction(collected, b, gama, mu, sigma_inv);
            predictions = [predictions; prediction];
        end
    end
    save('predictions.mat', 'predictions')
    results = predictions;
end

function result = testTidSubset(folder, subset, b, gama, mu, sigma_inv)
    
    subsetPredictions = [];
    
    % For all images in folder
    for j=1:length(subset)
        disp(j)
        imageName = subset(j,:)
        if (endsWith(imageName, '.bmp'))

            % Read image
            imagePath = char(strcat(folder, imageName))
            img = imread(imagePath);

            % Get features
            features = bliinds2_feature_extraction(img);
            scale_1 = transpose(features(:,1));
            scale_2 = transpose(features(:,2));
            scale_3 = transpose(features(:,3));
            collected = cat(2, scale_1, cat(2, scale_2, scale_3));

            % Compute predicted DMOS 
            prediction = bliinds_prediction(collected, b, gama, mu, sigma_inv)
            subsetPredictions = [subsetPredictions; prediction];
        end
    end
    save('subsetPredictions.mat', 'subsetPredictions')
    result = subsetPredictions;
end

function srocc = calculateTidSrocc(predictions)
    tidMosFile = fopen('../tid2008/mos_with_names.txt', 'r');
    tidMos = textscan(tidMosFile, '%f %s');

    values = tidMos{1};
    names = tidMos{2};
    
    subsetNames = [];
    subsetMos = [];
    subsetPredictions = [];
    
    for i=1:length(names)
        name = names(i);
        split = strsplit(name{1}, '_');
        temp = split{2};
        if strcmp(temp,'01') || strcmp(temp,'08') || strcmp(temp,'10') || strcmp(temp,'11')
            subsetMos = [subsetMos; values(i)];
            subsetPredictions = [subsetPredictions; predictions(i)];
            subsetNames = [subsetNames; name{1}];
        end
    end
    
    save('subset.mat', 'subsetNames');
    save('subsetMos.mat', 'subsetMos');
    
    srocc = corr(subsetMos, subsetPredictions, 'type', 'Spearman');
end

function srocc = calculateTidSubsetSrocc(data_folder, data_instances, output_folder, b, gama, mu, sigma_inv)
    tid_mos_file = fopen(data_instances, 'r');
    tid_mos = textscan(tid_mos_file, '%f %s');

    mos_values = tid_mos{1};
    names = tid_mos{2};

    results = [];
    wn_results = [];
    gblur_results = [];
    jpeg_results = [];
    jp2k_results = [];
    
    % For each image
    for i=1:length(names)
        original_name = names(i);
        split = strsplit(original_name{1}, '_');
        distortion_type = split{2};
        
        % Use only images with Gaussian noise, Gaussian blur, JPEG
        % compression, and JPEG2000 compression
        if strcmp(distortion_type, '01') || strcmp(distortion_type, '08') || strcmp(distortion_type, '10') || strcmp(distortion_type, '11')
            
            % Read image
            name = strcat(upper(split{1}), '_', split{2}, '_', split{3});
            image_path = char(strcat(data_folder, name))
            img = imread(image_path);

            % Extract features at 3 scales
            features = bliinds2_feature_extraction(img);
            scale_1 = transpose(features(:,1));
            scale_2 = transpose(features(:,2));
            scale_3 = transpose(features(:,3));
            scales = cat(2, scale_1, cat(2, scale_2, scale_3));

            % Compute predicted DMOS 
            prediction = bliinds_prediction(scales, b, gama, mu, sigma_inv)
            
            results = [results; [{name} mos_values(i) prediction]];
            if strcmp(distortion_type, '01')
                wn_results = [wn_results; [{name} mos_values(i) prediction]];
            elseif strcmp(distortion_type, '08')
                gblur_results = [gblur_results; [{name} mos_values(i) prediction]];
            elseif strcmp(distortion_type, '10')
                jpeg_results = [jpeg_results; [{name} mos_values(i) prediction]];
            elseif strcmp(distortion_type, '11')
                jp2k_results = [jp2k_results; [{name} mos_values(i) prediction]];
            end
        end
    end
    
    % Save data
    if ~isempty(wn_results)
        wn_output_file = strcat(output_folder, 'White_noise_predictions.csv');
        wn_output = [wn_results(:,1) wn_results(:,3)];
        writeData(wn_output_file, wn_output);
    end
    
    if ~isempty(gblur_results)
        gblur_output_file = strcat(output_folder, 'GBlur_predictions.csv');
        gblur_output = [gblur_results(:,1) gblur_results(:,3)];
        writeData(gblur_output_file, gblur_output);
    end
    
    if ~isempty(jpeg_results)
        jpeg_output_file = strcat(output_folder, 'JPEG_predictions.csv');
        jpeg_output = [jpeg_results(:,1) jpeg_results(:,3)];
        writeData(jpeg_output_file, jpeg_output);
    end
    
    if ~isempty(jp2k_results)
        jp2k_output_file = strcat(output_folder, 'JPEG2000_predictions.csv');
        jp2k_output = [jp2k_results(:,1) jp2k_results(:,3)];
        writeData(jp2k_output_file, jp2k_output);
    end
    
    if ~isempty(results)
        all_output_file = strcat(output_folder, 'All_predictions.csv');
        all_output = [results(:,1) results(:,3)];
        writeData(all_output_file, all_output);
    end
    
    % Create scatter plot
    mos = cell2mat(results(:,2));
    predictions = cell2mat(results(:,3));
    fig = figure();
    scatter(mos, predictions)
    figure_path = strcat(output_folder, 'Fig20.png');
    saveas(fig, figure_path);
    
    % Calculate SROCC scores for the different distortion types, and all
    wn_srocc = corr(cell2mat(wn_results(:,2)), cell2mat(wn_results(:,3)), 'type', 'Spearman')
    gblur_srocc = corr(cell2mat(gblur_results(:,2)), cell2mat(gblur_results(:,3)), 'type', 'Spearman')
    jpeg_srocc = corr(cell2mat(jpeg_results(:,2)), cell2mat(jpeg_results(:,3)), 'type', 'Spearman')
    jp2k_srocc = corr(cell2mat(jp2k_results(:,2)), cell2mat(jp2k_results(:,3)), 'type', 'Spearman')
    srocc = corr(mos, predictions, 'type', 'Spearman')
end

function writeData(file_path, data)
    file = fopen(file_path, 'w');
    for i=1:size(data, 1)
        fprintf(file, '%s;%f\n', data{i,:});
    end
    fclose(file);
end