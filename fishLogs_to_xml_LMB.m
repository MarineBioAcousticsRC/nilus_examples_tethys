% fishLogs_to_xml_LMB

% upload detections from manual logs to Tethys
% these logs were created using Logger in Triton
% this code will upload detections at the encounter level, since that's how
% I logged them
% currently optimized for fish, will probably need to modify for other
% species!
% code last updated 04-Nov-2025 LMB; lbaggett@ucsd.edu

%% edit me!

deployment = 'CHNMS_NO_03'; % deployment name, must match HARPdb names
xlsfile = 'M:\Fish\CHNMS_NO_03_fish.xlsx'; % file name for this sheet
log = readtable(xlsfile,'Sheet','Detections'); % load in detections
eff = readtable(xlsfile,'Sheet','MetaData'); % load in metadata
sp = {'UF310','UF440','bocaccio','midshipman','wseabass'}; % species code, all UF in my case
splatin = {'Actinopterygii','Actinopterygii','Sebastes paucispinis','Porichthys notatus','Atractoscion nobilis'}; % specific species abbreviation
ctype = 'chorus'; % call type
xml_out = 'M:\Fish\CHNMS_NO_03_logger_fish_choruses_LMB.xml'; % path to save Tethys format xml document
spd = 60*60*24; % seconds in day, for datenum conversion

% input methods/abstract info
p.methods = 'Manual logs using "Logger" in Triton, 7-day LTSAs from 10 - 1000 Hz.';
p.abstract = 'The fish choruses contained in this dataset were processed as part of the CADEMO analysis, to establish a baseline of biological acoustic behavior at a future offshore wind site. These choruses were logged by LMB using "Logger" in Triton. On-effort for all fish choruses.';
p.objectives = 'Understand fish chorusing at a future offshore wind site. Establish a baseline of acoustic behavior for fish chorusing before construction begins.';
p.software = 'Triton https://github.com/MarineBioAcousticsRC/Triton';
p.version = 'GitHub commit # acd3e2f6001e34f4e396450f72234b99e9658bb4';
p.algmethod = 'Manual logging by LMB.';
p.userid = 'lbaggett'; % person who uploaded the data

% input logger information
p.LTSAlength_hours = 168;
p.frequencyMax_Hz = 1000;

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
d.setId([deployment,'_logger_fish_choruses_',p.userid]); % unique ID for this file
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
h.AddAnyElement(algparmList,'LTSAlength_hours',num2str(p.LTSAlength_hours));
h.AddAnyElement(algparmList,'frequencyMax_Hz',num2str(p.frequencyMax_Hz));

% effort
effort = d.getEffort();
h.createRequiredElements(effort);
effort.setStart(h.timestamp(dbSerialDateToISO8601(eff.EffortStart)));
effort.setEnd(h.timestamp(dbSerialDateToISO8601(eff.EffortEnd)));

% add more kinds for the species we found
for k = 1:numel(splatin) % don't inlcude the last, since it's also Pp
    kinds = effort.getKind();
    kind = DetectionEffortKind();
    species = q.QueryTethys(char("lib:completename2tsn(""" + splatin{k} + """)")); % get the ITIS species code
    speciestype = SpeciesIDType();
    speciestype.setValue(h.toXsInteger(str2num(species)));
    kind.setSpeciesId(speciestype);
    kind.setCall(ctype);
    if contains(sp{k},'UF') % if this is an unknown fish species
        speciestype.setGroup(sp{k});
        kind.setSpeciesId(speciestype);
    end
    granularitytype = GranularityEnumType.fromValue('encounter');
    granularity = GranularityType();
    granularity.setValue(granularitytype);
    kind.setGranularity(granularity);
    kinds.add(kind);
end

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

        h.createElement(det,'Call'); % create a field for call type
        callList = det.getCall(); % grab the call element
        callList.add(ctype); % specify these are choruses
        
        % find the species match
        spmatch = strcmp(log.Comments(i),sp);
        species = q.QueryTethys(char("lib:completename2tsn(""" + splatin{spmatch} + """)")); % get the ITIS species code
        speciestype = SpeciesIDType();
        speciestype.setValue(h.toXsInteger(str2num(species))); % set the species type
        speciestype = SpeciesIDType();
        speciestype.setValue(h.toXsInteger(str2num(species))); % set the species type
        det.setSpeciesId(speciestype); % plug that in
        if contains(sp{spmatch},'UF') % if this is an unknown fish species
            speciestype.setGroup(sp{spmatch});
        end
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


