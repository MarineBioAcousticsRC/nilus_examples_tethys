%% humpback_nnet_to_xml_LMB.m

% 12/10/2025 LMB 2023a, lbaggett@ucsd.edu
% this script will take .mat files I created from the humpback whale neural
% network (Allen et al., 2021; https://doi.org/10.3389/fmars.2021.607321)
% upload minute bins of detections from the nnet output, and include
% information about the portions which have been manually verified with
% calculated error rates.

%% edit me!

deployment = 'CHNMS_NO_03'; % deployment name, must match HARPdb names
df = dir('M:\Mysticetes\Humpback_NNET\hump_nnet_no_threshold_3.92s\GPLReview_60s_fulldataset\CHNMS_NO_03\*.mat'); % path to outputted files
verified = dir('M:\Mysticetes\Humpback_NNET\hump_nnet_no_threshold_3.92s\GPLReview_60s_verified\CHNMS_NO_03\**\*.mat'); % path to verified files

eff.Start = [datetime('14-May-2023 00:00:00')]; % start time of effort
eff.End = [datetime('06-Nov-2024 20:57:13')]; % end time of effort
splatin = {'Megaptera novaeangliae'}; % specific species abbreviation
ctype = 'song'; % call type
xmlOutFolder = 'M:\Mysticetes\Humpback_NNET\hump_nnet_no_threshold_3.92s\GPLReview_60s_fulldataset'; % path to folder for saving Tethys format xml document
spd = 60*60*24; % seconds in day, for datenum conversion

% input methods/abstract info
p.methods = 'Humpback whale song was detected using a deep CNN that was previously trained using recordings of humpback whale song in the North Pacific (Allen et al., 2021). Acoustic data were decimated by a factor of 32 to include data up to 5 kHz, encompassing the range of humpback whale calls and matching the frequency range used in the original model development. The model transforms audio inputs into 3.92 s spectrograms and then passes these into the neural network, outputting a classification score between 0 and 1 representing the likelihood of that segment containing humpback song. To evaluate neural network performance, these labels were aggregated into 1-minute bins. If the median score within a bin exceeded 0.5, the minute was labeled as containing humpback song. A subset of the data (3\%) was evaluated by analyst LMB, and error rates per week were calculated based on the false negative and false positive rates within each week.';
p.abstract = 'The humpback song in this dataset was processed as part of the CADEMO analysis, to establish a baseline of biological acoustic behavior at a future offshore wind site. Humpback whale song was detected and classified using a neural network from Allen et al., 2021; a subset of the data was then manually verified using GPLReview to establish false positive and false negative rates.';
p.objectives = 'Understand humpback song at a future offshore wind site. Establish a baseline of acoustic behavior for humpback whale song before construction begins.';
p.software = 'Humpback whale neural network by Allen et al., 2021: https://doi.org/10.3389/fmars.2021.607321';
p.supportSoftware = 'GPLReview: https://github.com/MarineBioAcousticsRC/GPLReview';
p.algmethod = 'Allen et al., 2021 CNN labeled 3.92 s data segments with a score between 0 and 1 for humpback whale song. To evaluate performance, these labels were aggregated into 1-minute bins. If the median score within a bin exceeded 0.5, the minute was labeled as containing humpback song (score = 1). If the median score was below 0.5, the minute was labeled as NOT containing humpback song (score = 0). A subset of the data (3\%) was evaluated by analyst LMB, and error rates per week were calculated based on the false negative and false positive rates within each week.';
p.userid = 'lbaggett'; % person who uploaded the data
p.binDur = 1; % bin duration (minutes)
p.binScoreThreshold = 0.5; % the median bin score for being labeled as true

%% organize data

allDets = []; % preallocate to save
for j = 1:length(df)
    load(fullfile(df(j).folder,df(j).name)); % load the file
    allDets = [allDets;[[Times.julian_start_time]',cell2mat(Labels)]]; % save bin times and labels
end

allVer = []; % preallocate to save verified detections
for j = 1:length(verified)
    load(fullfile(verified(j).folder,verified(j).name)); % load the file
    allVer = [allVer;[[Times.julian_start_time]',cell2mat(Labels)]]; % save bin times and labels
end

% now, compare for quality assurance section as per schema: Detection is either unverified, valid, invalid
% unverified = nan; valid = 1; invalid = 0;
[~, ia, ~] = intersect(allDets(:,1),allVer(:,1)); % find indices of verified bins in the large array
qa = nan(size(allDets,1),1); % preallocate for quality assurance
for k = 1:length(ia)
    if allDets(ia(k),2) == allVer(k,2) % if the label from unverified matches verified label
        qa(ia(k),1) = 1; % valid label
    elseif allDets(ia(k),2) ~= allVer(k,2) % if the label from inverified is different than verified label
        qa(ia(k),1) = 0; % invalid label
    end
end
allDets = [allDets,qa]; % add qa column to detection table

%% write XML

% this method uses Nilus to connect to the Tethys server, create an XML
% document, and then upload the table with detections
% https://tethys.sdsu.edu/documentation/ for more information!


fprintf('WARNING: You are about to upload to Tethys. Have you updated your metadata appropriately? Be sure to update the section above! \n')
% keyboard % if you have updated your metadata and are truly ready to upload, comment out this line

q=dbInit('Server','breach.ucsd.edu','Port',9779); % connect to Tethys server
% dbOpenSchemaDescription(q,'Detections'); % open locaize schema (for our reference) % look at all the information!

import nilus.* % import Nilus, this provides Java objects that correspond to XML elements

% create elements
d = Detections();
h = Helper();
m = MarshalXML();

m.marshal(d); % generate our XML (empty right now)
h.createRequiredElements(d); % create the required elements for our XML file

% identifiers
d.setUserId(p.userid); % the name of the person who processed the data
d.setId([deployment,'_humpback_nnet_',p.userid]); % unique ID for this file
data_source = d.getDataSource();
data_source.setDeploymentId(deployment); % deployment ID

% descriptions
h.createElement(d,'Description');
description = d.getDescription();
% populate some information for people in the future! where can they
% find a description of the methods that will be helpful for using this
% data properly?
description.setAbstract(p.abstract);
description.setMethod(p.methods);
description.setObjectives(p.objectives);

% define information about the algorithm
alg = d.getAlgorithm();
h.createRequiredElements(alg);
alg.setSoftware(p.software);
alg.setMethod(p.algmethod)

% add in some more specific info from detection
h.createElement(alg,'Parameters')
algparm = alg.getParameters();
algparmList = algparm.getAny();
h.AddAnyElement(algparmList,'binScoreThreshold',num2str(p.binScoreThreshold));

% effort
effort = d.getEffort();
h.createRequiredElements(effort);
effort.setStart(h.timestamp(dbSerialDateToISO8601(eff.Start)));
effort.setEnd(h.timestamp(dbSerialDateToISO8601(eff.End)));

% add more kinds for the species we found
kinds = effort.getKind();
kind = DetectionEffortKind();
species = q.QueryTethys(char("lib:completename2tsn(""" + splatin + """)")); % get the ITIS species code
speciestype = SpeciesIDType();
speciestype.setValue(h.toXsInteger(str2num(species)));
kind.setSpeciesId(speciestype);
kind.setCall(ctype);
granularitytype = GranularityEnumType.fromValue('binned');
granularity = GranularityType();
granularity.setValue(granularitytype);
kind.setGranularity(granularity);
kinds.add(kind);
granularity.setBinSizeMin(java.lang.Double(p.binDur));

d.setEffort(effort)

% create detection field
on = d.getOnEffort() ;
detList = on.getDetection();

fprintf('Beginning to add detections. This may take a while, please be patient. \n')

for i = 1:height(allDets) % for each bin

    det = Detection(); % grab the detection object

    det.setStart(h.timestamp(dbSerialDateToISO8601(allDets(i,1)))) % input start time of this bin

    speciestype.setValue(h.toXsInteger(str2num(species))); % set the species type
    det.setSpeciesId(speciestype); % plug that in

    h.createElement(det,'Call'); % create a field for call type
    callList = det.getCall(); % grab the call element
    callList.add(ctype); % specify these are song

    h.createElement(det,'Parameters');
    params = det.getParameters();
    params.setScore(java.lang.Double(allDets(i,2))); % specify the score
    if isnan(allDets(i,3)) % if we have a nan = unverified
        params.setQualityAssurance(QualityValueBasic.UNVERIFIED);
    elseif allDets(i,3) == 0 % if we have a 0 = invalid label
        params.setQualityAssurance(QualityValueBasic.INVALID);
    elseif allDets(i,3) == 1 % if we have a 1 = valid label
        params.setQualityAssurance(QualityValueBasic.VALID);
    end

    detList.add(det); % add this detection to the list

end

xml_out = [xmlOutFolder,'\',deployment,'_humpback_nnet_song_detections_',p.userid,'.xml'];
fprintf('XML document formatted for Tethys saving at: %s\n',xml_out)
m.marshal(d, xml_out) % save the xml file in your path from above
fprintf('XML file saved. Now launching submission interface. Please upload the XML file you just generated. \n')


dbSubmit('Server','breach.ucsd.edu','Port',9779) % launch the submission interface


