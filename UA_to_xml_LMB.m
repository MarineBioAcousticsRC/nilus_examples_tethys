%% UA_to_xml_LMB

% upload UA detections to Tethys
% this code will upload detections at the encounter level
% input files are manual logs!
% code last updated 04-Nov-2025 LMB; lbaggett@ucsd.edu

%% edit me!

deployment = 'BAJA_GI_05'; % deployment name, must match HARPdb names
xlsfile = 'L:\Baja\UA\UA_CMS_Baja_GI_05.xlsx'; % file name for this sheet
log = readtable(xlsfile,'Sheet','Detections'); % load in detections
eff = readtable(xlsfile,'Sheet','MetaData'); % load in metadata
sp = "Homo sapiens"; % species code
ctype = "Active Sonar"; % call type
csubtype = "Ultrasonic Antifouling"; % call subtype
uploadFlag = 1; % 1; % flag for uploading to Tethys, yes (1) or no (0). if you're not Lauren, you need to change these settings!!!
xml_out = 'L:\Baja\UA\BAJA_GI_05_UA_CMS.xml'; % path to save Tethys format xml document
spd = 60*60*24; % seconds in day, for datenum conversion

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
    d.setUserId('cschoenbeck'); % the name of the person who processed the data
    d.setId([deployment,'_UA_encounters_CMS']); % unique ID for this file
    data_source = d.getDataSource();
    data_source.setDeploymentId(deployment); % deployment ID

    % descriptions
    h.createElement(d,'Description');
    description = d.getDescription();
    % populate some information for people in the future! where can they
    % find a description of the methods that will be helpful for using this
    % data properly?
    description.setAbstract('The ultrasonic antifouling sonar pings in this dataset were processed to maintain our long-term acoustic monitoring timeseries for this region. These encouters were detected by manual logs. NO UA FOUND IN THIS DEPLOYMENT.');
    description.setMethod('For a description of this analysis, see the "Manual detection of anthropogenic signals" section of the methods in Trickey et al., 2022 (https://doi.org/10.1038/s42003-022-03959-9). Detections verified at the encounter level. Encounters calculated with minimum gap time between sessions as 15 minutes (based on Rice et al., 2017; https://doi.org/10.3354/meps12158.');
    description.setObjectives('Maintain MFA sonar timeseries at GI.');

    % define information about the algorithm
    alg = d.getAlgorithm();
    h.createRequiredElements(alg);
    alg.setSoftware('Triton https://github.com/MarineBioAcousticsRC/Triton');
    alg.setVersion('GitHub commit # a79f47514a5985978a38fe857f3bad8dc150d7cf');
    alg.setMethod('Manual logging using the Logger remora by CMS. Settings are: 1 hr LTSAs, brightness 25, contrast 100.')

    % effort
    effort = d.getEffort();
    h.createRequiredElements(effort);
    effort.setStart(h.timestamp(dbSerialDateToISO8601(eff.EffortStart)));
    effort.setEnd(h.timestamp(dbSerialDateToISO8601(eff.EffortEnd)));

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

    if height(log) > 0 % if we have detections in this spreadsheet

        for i = 1:height(log) % for each bin

            det = Detection(); % grab the detection object

            det.setStart(h.timestamp(dbSerialDateToISO8601(log.StartTime(i)))) % input start time of this bin
            det.setEnd(h.timestamp(dbSerialDateToISO8601(log.EndTime(i)))) % set end time
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

        fprintf('XML document formatted for Tethys saving at: %s\n',xml_out)
        m.marshal(d, xml_out) % save the xml file in your path from above
        fprintf('XML file saved. Now launching submission interface. Please upload the XML file you just generated. \n')

    elseif height(log) == 0 % if we have no detections
        m.marshal(d, xml_out) % save the xml file in your path from above
        fprintf('XML document formatted for Tethys saving at: %s\n',xml_out)
        fprintf('XML file saved, no detections in file. Now launching submission interface. Please upload the XML file you just generated. \n')
    end

    dbSubmit('Server','breach.ucsd.edu','Port',9779) % launch the submission interface

end

