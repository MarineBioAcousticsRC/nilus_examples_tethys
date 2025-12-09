%% SPICE_odontclick_multispecies_detections_to_xml_LMB.m

% 12/05/2025 MATLAB 2023a, lbaggett@ucsd.edu
% this script will take ID files containings labels from MULTIPLE species
% and make tables that can be uploaded to Tethys
% this code works for data processed at the CLICK LEVEL or the BIN LEVEL. if you did not
% process your data at this resolution (like if you have enconters or something), you will need to make
% modifications.

% this code also has been written to include subtypes and also to
% accomidate a family-level classification. you'll likely have to modify
% for your specific species accordingly, so don't just run this blindly.

%% edit me!

deployment = 'CHNMS_NO_03';
id = dir('M:\Odonts\detEdited_ID\CHNMS_NO_03\*ID1.mat'); % path to your ID2 files
eff.Start = [datetime('14-May-2024 00:00:00')]; % start time of effort
eff.End = [datetime('06-Nov-2024 20:57:13')]; % end time of effort
unkFlag = 0; % 1 if this is an unidentified BW click type, 0 if you know the species
fourFlag = 0; % 1 if this is a 4ch, 0 if single
ch = 1; % if you have multiple channels, the channel that you processed
p.binDur = 1; % 1 minute
xmlOutFolder = 'M:\Odonts\detEdited_ID\CHNMS_NO_03'; % path to save Tethys format xml document
spd = 60*60*24; % seconds in day, for datenum conversion

sp = {'DdDcTt','Gg','LoA','PhA','PhB'}; % set the species labels from the ID files that you want to upload
splatin = {'Delphinidae','Grampus griseus','Lagenorhynchus obliquidens','Phocoena phocoena','Phocoena phocoena'}; % the corresponding latin species names for the codes above
% *** this code is modified to specify call types for Lo and Pp, if you
% don't have call subtypes then you'll need to modify this

% set some params manually since in this case my intern didn't save the
% metadata files, just a screenshot
p.dBppThreshold = 118;
p.bpRanges = [5, 155];
p.tfFullFile = 'G:\Shared drives\MBARC_TF\900-999\958\958_201020_B_HARP.tf';
p.neuralNetwork = 'CHNMS_NO_combined_trainedNetwork_bin.mat';

% input methods/abstract info
p.methods = 'For a description of the general workflow, see Frasier et al 2017 (https://doi.org/10.1371/journal.pcbi.1005823) and Frasier 2021 (https://doi.org/10.1371/journal.pcbi.1009613). Detections verified at the minute bin level. This work will be published by Baggett et al.';
p.abstract = 'The echolocation clicks contained in this dataset were processed as part of the CADEMO analysis, to establish a baseline of odontocete acoustic behavior at a future offshore wind site. These calls were detected and classified using Triton and verified using DetEdit. Analyst Joey Andres verified detections, as supervised by Lauren Baggett. We were on effort for all odontocete echolocation clicks. Bins labeled just as Delphinidae are likely bottlenose or common dolphins.';
p.objectives = 'Understand odontocete acoustic presence at a future offshore wind site. Establish a baseline of acoustic behavior for odontocetes (clicks) before construction begins.';
p.software = 'Triton https://github.com/MarineBioAcousticsRC/Triton';
p.version = 'GitHub commit # acd3e2f6001e34f4e396450f72234b99e9658bb4';
p.algmethod = 'Machine learning workflow, all detections verified by analyst JFA using DetEdit.';
p.userid = 'lbaggett'; % person who uploaded the data

%% generate effort template table

% generate an empty table for binning, calculate effort, etc
eff.diffSec = seconds(eff.End-eff.Start) ; % duration of effort
eff.bins = eff.diffSec/(60*p.binDur); % find number of bins at your desired resolution
binEffort = intervalToBinTimetable_LMB(eff.Start,eff.End,p);
binEffort.Properties.VariableNames{1} = 'bin';
binEffort.Properties.VariableNames{2} = 'sec';

%% put all IDs into one table

allID = []; % preallocate
for ip = 1:length(id) % for each ID file
    load(fullfile(id(ip).folder, id(ip).name)) % load the file
    allID = [allID; zID]; % concatenate vertically into the preallocated mega matrix
end

%% upload to Tethys

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
d.setId([deployment,'_odontocete_SPICE_click_detections_',p.userid]); % unique ID for this file
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
alg.setVersion(p.version);
alg.setMethod(p.algmethod)

% add in some more specific info from detection
h.createElement(alg,'Parameters')
algparm = alg.getParameters();
algparmList = algparm.getAny();
h.AddAnyElement(algparmList,'dbPP_threshold',num2str(p.dBppThreshold));
h.AddAnyElement(algparmList,'bandpass_lowerEdge_Hz',num2str(p.bpRanges(1)));
h.AddAnyElement(algparmList,'bandpass_upperEdge_Hz',num2str(p.bpRanges(2)));
h.AddAnyElement(algparmList,'tf_path',p.tfFullFile);
h.AddAnyElement(algparmList,'neural_network',p.neuralNetwork);

% effort
effort = d.getEffort();
h.createRequiredElements(effort);
effort.setStart(h.timestamp(dbSerialDateToISO8601(eff.Start)));
effort.setEnd(h.timestamp(dbSerialDateToISO8601(eff.End)));

% kinds (info about species, call type, granularity
kinds = effort.getKind();
kind = DetectionEffortKind();
% kind.setCall('Clicks');
% granularitytype = GranularityEnumType.fromValue('binned');
% granularity = GranularityType();
% granularity.setValue(granularitytype);
% kind.setGranularity(granularity);
% kinds.add(kind);
% add more kinds for the species we found
kind = DetectionEffortKind();
for k = 1:numel(splatin) % don't inlcude the last, since it's also Pp
    kind = DetectionEffortKind();
    species = q.QueryTethys(char("lib:completename2tsn(""" + splatin{k} + """)")); % get the ITIS species code
    speciestype = SpeciesIDType();
    speciestype.setValue(h.toXsInteger(str2num(species)));
    kind.setSpeciesId(speciestype);
    kind.setCall('Clicks');
    if ~strcmp(sp{k},'Gg') % | strcmp(splatin{k},'Phocoena phocoena') % if this is LoA or Pp
        params = javaObject('nilus.DetectionEffortKind$Parameters'); % kind.getParameters() was returning empty, so this is my solution to create the java object directly
        params.setSubtype(sp{k}) % add in the subtype information
        kind.setParameters(params)
    end
    granularitytype = GranularityEnumType.fromValue('binned');
    granularity = GranularityType();
    granularity.setValue(granularitytype);
    granularity.setBinSizeMin(java.lang.Double(p.binDur));
    % granularity.setFirstBinStart(h.timestamp(dbSerialDateToISO8601(binEffort.tbin(1))))
    kind.setGranularity(granularity);
    kinds.add(kind);
end

% granularity.setBinSizeMin(java.lang.Double(p.binDur));
% granularity.setFirstBinStart(h.timestamp(dbSerialDateToISO8601(binEffort.tbin(1))))
d.setEffort(effort)

% create detection field
on = d.getOnEffort() ;
detList = on.getDetection();

fprintf('Beginning to bin detections and then add them to XML. This may take a while, please be patient. \n')

thisSpClicks = [];
for k = 1:length(sp) % for each species selected

    % generate an empty table for binning, calculate effort, etc
    thisSpeciesBinEffort = binEffort; % make a table by copying the template

    % find ITIS code for this species
    species = q.QueryTethys(char("lib:completename2tsn(""" + splatin{k} + """)")); % get the ITIS species code

    % find associated labels for each species
    idx = find(strcmp(mySpID,sp{k})); % put in your desired species ID here
    labels = allID(:,2) == idx;
    thisSpClicks = [thisSpClicks;allID(labels,1)];
    clickTimes = datetime(thisSpClicks(:,1),'convertfrom','datenum'); % grab the times, convert to datetime

    % bin detections
    [counts, edges] = histcounts(clickTimes,[thisSpeciesBinEffort.tbin;(thisSpeciesBinEffort.tbin(end)+minute(p.binDur))]); % bin # of calls within each minute
    thisSpeciesBinEffort.ClickCounts = counts';
    thisSpeciesBinEffort.Properties.VariableNames = {'Effort_Bin','Effort_seconds','Click_Counts'};
    thisSpeciesBinEffort = thisSpeciesBinEffort(thisSpeciesBinEffort.Click_Counts>0,:); % remove minutes without detections for this species

    for b = 1:height(thisSpeciesBinEffort) % for each positive minute for this species

        det = Detection();

        det.setStart(h.timestamp(dbSerialDateToISO8601(thisSpeciesBinEffort.tbin(b)))) % input start time of this bin
        det.setEnd(h.timestamp(dbSerialDateToISO8601(thisSpeciesBinEffort.tbin(b) + (thisSpeciesBinEffort.Effort_seconds(b)/spd)))) % set end time, useful because sometimes we have partial effort
        speciestype = SpeciesIDType();
        speciestype.setValue(h.toXsInteger(str2num(species))); % set the species type
        det.setSpeciesId(speciestype); % plug that in

        h.createElement(det,'Call'); % create a field for call type
        callList = det.getCall(); % grab the call element
        callList.add('Clicks'); % specify these are clicks

        % add in subtypes
        if ~strcmp(sp{k},'Gg') 
            h.createElement(det,'Parameters');
            params = det.getParameters();
            params.setSubtype(sp{k}); % specify the subtype
        end

        detList.add(det); % add this detection

    end

    fprintf('Finished adding detections for species %s\n',splatin{k})

end

xml_out = [xmlOutFolder,'\',deployment,'_odontocete_SPICE_click_detections_',p.userid,'.xml'];
fprintf('XML document formatted for Tethys saving at: %s\n',xml_out)
m.marshal(d, xml_out) % save the xml file in your path from above
fprintf('XML file saved. Now launching submission interface. Please upload the XML file you just generated. \n')

dbSubmit('Server','breach.ucsd.edu','Port',9779) % launch the submission interface


 