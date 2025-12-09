%% MFAS_to_xml_LMB

% upload MFA detections to Tethys
% this code will upload detections at the encounter level, as Jenny was
% uploading for years
% input files are TPWS2, verified to only contain true detections for MFAS
% code last updated 04-Nov-2025 LMB; lbaggett@ucsd.edu

%% edit me!

deployment = 'SOCAL_N_73'; % deployment name, must match HARPdb names
tpws2 = dir('A:\SOCAL\MFAS\SOCAL_N_73_TPWS\*TPWS2.mat'); % list your TPWS2 files
sp = "Homo sapiens"; % species code
ctype = "Active Sonar"; % call type
csubtype = "MFA<5kHz"; % call subtype
uploadFlag = 1; % 1; % flag for uploading to Tethys, yes (1) or no (0). if you're not Lauren, you need to change these settings!!!
xml_out = 'A:\SOCAL\MFAS\SOCAL_N_73_TPWS\SOCAL_N_73_MFAS_LMB.xml'; % path to save Tethys format xml document
spd = 60*60*24; % seconds in day, for datenum conversion
eff.Start = [datetime('12-Nov-2022 18:00:00')]; % start time of effort
eff.End = [datetime('18-Apr-2023 15:36:15')]; % end time of effort

%settings for encounters, modify if you want
p.gth =  .5;    % gap time in hrs between sessions
p.minBout = 0;  % minimum bout duration in seconds
p.ltsaMax = 6;  % ltsa maximum duration per session
p.tfFullFile = 'G:\Shared drives\MBARC_TF\900-999\990\990_220823_A_HARP.tf' % path to transfer function used

%% calculate encounters

allMTT = []; % preallocate to save all times

for i = 1:length(tpws2) % for each TPWS2 files

    load(fullfile(tpws2(i).folder,tpws2(i).name),'MTT'); % load just timing info, save memory
    allMTT = [allMTT;MTT]; % save times in larger array

end

if height(allMTT>0)
    [nb,eb,sb,bd] = calculate_bouts(allMTT,p); % this function is in DetEdit
end

%% write XML

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
    d.setId([deployment,'_MFA_encounters_LMB']); % unique ID for this file
    data_source = d.getDataSource();
    data_source.setDeploymentId(deployment); % deployment ID

    % descriptions
    h.createElement(d,'Description');
    description = d.getDescription();
    % populate some information for people in the future! where can they
    % find a description of the methods that will be helpful for using this
    % data properly?
    description.setAbstract('The MFA sonar pings in this dataset were processed to maintain our long-term acoustic monitoring timeseries for this region. These encouters were detected using the MFA sonar detector and verified using DetEdit.');
    description.setMethod('For a description of this analysis, see the "Anthropogenic Sounds" section of the methods in MPLTM668 (https://www.cetus.ucsd.edu/reports.html). Detections verified at the ping level, data is inputted here as encounters. Encounters calculated with minimum gap time between sessions as 30 minutes. Minimum bout duration 0 s.');
    description.setObjectives('Maintain MFA sonar timeseries in SOCAL.');

    % define information about the algorithm
    alg = d.getAlgorithm();
    h.createRequiredElements(alg);
    alg.setSoftware('MFA sonar detector: frosty.ucsd.edu\\MBARC_ALL\Training\Detectors\MFA sonar detector');
    alg.setMethod('MFA sonar detector, all detections verified by analyst LMB/CMS/NP using DetEdit.')
    % add in some more specific info from detection
    h.createElement(alg,'Parameters')
    algparm = alg.getParameters();
    algparmList = algparm.getAny();
    h.AddAnyElement(algparmList,'tf_path',p.tfFullFile);

    % effort
    effort = d.getEffort();
    h.createRequiredElements(effort);
    effort.setStart(h.timestamp(dbSerialDateToISO8601(eff.Start)));
    effort.setEnd(h.timestamp(dbSerialDateToISO8601(eff.End)));

    % kinds (info about species, call type, granularity)
    kinds = effort.getKind();
    kind = DetectionEffortKind();
    % set species
    species = q.QueryTethys(char("lib:completename2tsn(""" + sp + """)")); % get the ITIS species code
    speciestype = SpeciesIDType();
    speciestype.setValue(h.toXsInteger(str2num(species)));
    kind.setSpeciesId(speciestype);
    % set call and subtype
    kind.setCall(ctype);
    params = javaObject('nilus.DetectionEffortKind$Parameters'); % kind.getParameters() was returning empty, so this is my solution to create the java object directly
    params.setSubtype(csubtype)
    kind.setParameters(params)
    % set granularity
    granularitytype = GranularityEnumType.fromValue('encounter');
    granularity = GranularityType();
    granularity.setValue(granularitytype);
    kind.setGranularity(granularity);
    kinds.add(kind);
    d.setEffort(effort)

    % create detection field
    on = d.getOnEffort() ;
    detList = on.getDetection();

    fprintf('Beginning to add detections. This may take a while, please be patient. \n')

    if exist('sb','var')

        for i = 1:height(sb) % for each bin

            det = Detection(); % grab the detection object

            det.setStart(h.timestamp(dbSerialDateToISO8601(sb(i)))) % input start time of this bin
            det.setEnd(h.timestamp(dbSerialDateToISO8601(eb(i)))) % set end time
            speciestype.setValue(h.toXsInteger(str2num(species))); % set the species type
            det.setSpeciesId(speciestype); % plug that in

            h.createElement(det,'Call'); % create a field for call type
            callList = det.getCall(); % grab the call element
            callList.add(ctype); % specify these are sonar pings
            h.createElement(det,'Parameters');
            params = det.getParameters();
            params.setSubtype(csubtype); % specify the subtype

            detList.add(det); % add this detection to the list

        end

    end

    fprintf('XML document formatted for Tethys saving at: %s\n',xml_out)
    m.marshal(d, xml_out) % save the xml file in your path from above
    fprintf('XML file saved. Now launching submission interface. Please upload the XML file you just generated. \n')

    dbSubmit('Server','breach.ucsd.edu','Port',9779) % launch the submission interface

end

