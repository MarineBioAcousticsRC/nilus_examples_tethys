%% SPICE_odontclick_detections_to_xml_LMB.m

% 07/25/2025 LMB 2023a, lbaggett@ucsd.edu
% this script will take ID2 files for a given species and make tables that
% can be uploaded to Tethys.
% this code works for data processed at the CLICK LEVEL. if you did not
% process your data at this resolution, you will need to make
% modifications.
% you MUST use ID2 files (contain only one species). if you have ID1 files
% with detections for multiple species, stop here and make ID2 files.

% for the duration of the deployment, make a table with time bins,
% calculated effort, and number of clicks recorded in that time bin.

%% edit me!

deployment = 'SOCAL_W_08'
id = dir('K:\W\W_08\SOCAL_W_08_Bb_TPWS2\*ID2.mat'); % path to your ID2 files
load('K:\W\W_08\SOCAL_W_08_detector_params.mat'); % path to detector metadata
eff.Start = [datetime('09-Nov-2024 19:00:00')]; % start time of effort
eff.End = [datetime('17-Apr-2025 21:10:00')]; % end time of effort
sp = "Berardius bairdii"; % species name
unkFlag = 0; % 1 if this is an unidentified BW click type, 0 if you know the species
fourFlag = 0; % 1 if this is a 4ch, 0 if single
ch = 1; % if you have multiple channels, the channel that you processed
p.binDur = 1; % 1 minute
uploadFlag = 1; % 1; % flag for uploading to Tethys, yes (1) or no (0). if you're not Lauren, you need to change these settings!!!
xml_out = 'K:\W\W_08\SOCAL_W_08_Bb_TPWS2\SOCAL_W_08_Bb_Tethys.xml'; % path to save Tethys format xml document
spd = 60*60*24; % seconds in day, for datenum conversion

%% group effort in bins

eff.diffSec = seconds(eff.End-eff.Start) ; % duration of effort
eff.bins = eff.diffSec/(60*p.binDur); % find number of bins at your desired resolution

% convert intervals in bins 
binEffort = intervalToBinTimetable_LMB(eff.Start,eff.End,p); 
binEffort.Properties.VariableNames{1} = 'bin';
binEffort.Properties.VariableNames{2} = 'sec';

%% group detections in bins

load([id.folder,'\',id.name]); % load in the ID2 file
clickTimes = datetime(zID(:,1),'convertfrom','datenum'); % grab the times, convert to datetime
[counts, edges] = histcounts(clickTimes,[binEffort.tbin;(binEffort.tbin(end)+minute(1))]); % bin # of calls within each minute
binEffort.ClickCounts = counts';
binEffort.Properties.VariableNames = {'Effort_Bin','Effort_seconds','Click_Counts'};

% writematrix('binEffort',[id.folder,'\',id.name,'_1min_clickCounts.csv']);

%% upload to Tethys

% this method uses Nilus to connect to the Tethys server, create an XML
% document, and then upload the table with detections
% https://tethys.sdsu.edu/documentation/ for more information!

if uploadFlag == 1

    fprintf('WARNING: You are about to upload to Tethys. Have you updated your metadata appropriately? Be sure to update the section below! \n')
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
    d.setUserId('lbaggett'); % the name of the person who processed the data
    d.setId([deployment,'_Bb_SPICE_click_detections']); % unique ID for this file
    data_source = d.getDataSource();
    data_source.setDeploymentId(deployment); % deployment ID

    % descriptions
    h.createElement(d,'Description');
    description = d.getDescription();
    % populate some information for people in the future! where can they
    % find a description of the methods that will be helpful for using this
    % data properly?
    description.setAbstract('The echolocation clicks contained in this dataset were processed to maintain our long-term beaked whale monitoring timeseries for this region. These calls were detected and classified using Triton and verified using DetEdit.');
    description.setMethod('For a description of this analysis, see the "Beaked Whale" section of the methods in MPLTM668 (https://www.cetus.ucsd.edu/reports.html). For a description of the general workflow, see Frasier et al 2017 (https://doi.org/10.1371/journal.pcbi.1005823) and Frasier 2021 (https://doi.org/10.1371/journal.pcbi.1009613). Detections verified at the click level, data is inputted here as number of clicks per minute bin.');
    description.setObjectives('Maintain long-term beaked whale timeseries in Southern California. Detect at the click-level for density estimation.');
    
    % define information about the algorithm
    alg = d.getAlgorithm();
    h.createRequiredElements(alg);
    alg.setSoftware('Triton https://github.com/MarineBioAcousticsRC/Triton');
    alg.setVersion('GitHub commit # acd3e2f6001e34f4e396450f72234b99e9658bb4');
    alg.setMethod('Machine learning workflow, all detections verified by analyst LMB using DetEdit.')

    % add in some more specific info from detection
    h.createElement(alg,'Parameters')
    algparm = alg.getParameters();
    algparmList = algparm.getAny();
    h.AddAnyElement(algparmList,'dbPP_threshold',num2str(p.dBppThreshold));
    h.AddAnyElement(algparmList,'bandpass_lowerEdge_Hz',num2str(p.bpRanges(1)));
    h.AddAnyElement(algparmList,'bandpass_upperEdge_Hz',num2str(p.bpRanges(2)));
    h.AddAnyElement(algparmList,'tf_path',p.tfFullFile);
    h.AddAnyElement(algparmList,'neural_network','nnet_bw_SOCAL_512HL_spectraOnly_trainedNetwork_bin.mat');

    % effort
    effort = d.getEffort();
    h.createRequiredElements(effort);
    effort.setStart(h.timestamp(dbSerialDateToISO8601(eff.Start)));
    effort.setEnd(h.timestamp(dbSerialDateToISO8601(eff.End)));

    % kinds (info about species, call type, granularity
    kinds = effort.getKind();
    kind = DetectionEffortKind();
    if unkFlag == 0 % if we know the species
        species = q.QueryTethys(char("lib:completename2tsn(""" + sp + """)")); % get the ITIS species code
        speciestype = SpeciesIDType();
        speciestype.setValue(h.toXsInteger(str2num(species)));
        kind.setSpeciesId(speciestype);
    elseif unkFlag == 1; % if this is an unidentified species
        species = q.QueryTethys(char("lib:completename2tsn(""Hyperoodontidae"")")); % get the ITIS species code
        speciestype = SpeciesIDType();
        speciestype.setValue(h.toXsInteger(str2num(species)));
        speciestype.setGroup(sp);
        kind.setSpeciesId(speciestype);
    end
    kind.setCall('Clicks');
    granularitytype = GranularityEnumType.fromValue('binned');
    granularity = GranularityType();
    granularity.setValue(granularitytype);
    kind.setGranularity(granularity);
    kinds.add(kind);
    granularity.setBinSizeMin(java.lang.Double(p.binDur));
    granularity.setFirstBinStart(h.timestamp(dbSerialDateToISO8601(binEffort.tbin(1))))
    d.setEffort(effort)

    % create detection field
    on = d.getOnEffort() ;
    detList = on.getDetection();

    fprintf('Beginning to add detections. This may take a while, please be patient. \n')

    % remove rows with no detections
    binEffort = binEffort(binEffort.Click_Counts>0,:);

    for i = 1:height(binEffort) % for each bin

        det = Detection();

        det.setStart(h.timestamp(dbSerialDateToISO8601(binEffort.tbin(i)))) % input start time of this bin
        det.setEnd(h.timestamp(dbSerialDateToISO8601(binEffort.tbin(i) + (binEffort.Effort_seconds(i)/spd)))) % set end time, useful because sometimes we have partial effort
        speciestype.setValue(h.toXsInteger(str2num(species))); % set the species type
        det.setSpeciesId(speciestype); % plug that in
        det.setCount(h.toXsInteger(binEffort.Click_Counts(i))) % set the number of clicks per bin

        h.createElement(det,'Call'); % create a field for call type
        callList = det.getCall(); % grab the call element
        callList.add('Clicks'); % specify these are clicks

        if fourFlag == 1
            h.createElement(det,'Channel'); % create field for channel number
            det.setChannel(h.toXsInteger(ch))
        end

        % add a parameter for bin effort so we don't need to recalcualte it
        % every time (future me will be happy :)
        % h.createElement(det,'Parameters');
        % params = det.getParameters();
        % h.createElement(params,'UserDefined');
        % userdef = params.getUserDefined();
        % userdefList = userdef.getAny();
        % h.AddAnyElement(userdefList,'Bin_Effort_seconds',num2str(binEffort.Effort_seconds(i)));

        detList.add(det);

    end
    
    fprintf('XML document formatted for Tethys saving at: %s\n',xml_out)
    m.marshal(d, xml_out) % save the xml file in your path from above
    fprintf('XML file saved. Now launching submission interface. Please upload the XML file you just generated. \n')

    dbSubmit('Server','breach.ucsd.edu','Port',9779) % launch the submission interface
    
end

 