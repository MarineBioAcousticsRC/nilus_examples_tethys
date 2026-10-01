%% shipDetector_to_xml_NP.m

% upload verified ship-presence detections to Tethys
% these ships were detected using the "Ship Detector" remora in Triton, then
% verified/reduced to start/end times of ship presence, one .mat file per
% deployment (variable "times", an Nx2 array of datenum start/end times).

% this version loops through every site folder in a region's ShipTimes
% directory, looks up each site's real Tethys deployment(s), matches each
% ship .mat file to its deployment by deployment number (since filenames
% aren't consistently the same text as the Tethys deployment ID), and
% uploads one XML per deployment.

%% edit me!

region = 'GofAK'; % 'GofAK', 'CentralPac', 'CCE', or 'WAT' -- everything below this block is set automatically from this choice

sp = "Homo sapiens"; % species code
ctype = "Ship"; % call type
csubtype = "Broadband"; % call subtype
uploadFlag = 1; % 1; % flag for uploading to Tethys, yes (1) or no (0). if you're not Natalie, you need to change these settings!!!
spd = 60*60*24; % seconds in day, for datenum conversion

p.software = 'Triton https://github.com/MarineBioAcousticsRC/Triton';
p.algmethod = 'Ship presence detected using the "Ship Detector" remora in Triton, verified by NP.';
p.userid = 'nposdaljian'; % person who uploaded the data
p.initials = 'NP'; % used in output XML filenames

p.methods = 'Ship presence was identified using the "Ship Detector" remora in Triton. This dataset is used to account for periods when recording effort for the co-located sperm whale click detection dataset was compromised by ship noise masking.';
p.abstract = 'This dataset contains verified ship-presence detections at passive acoustic monitoring sites, identified using the "Ship Detector" remora in Triton. ***THIS IS THE CORRESPONDING SHIP DETECTION FILE FOR THE SPERM WHALE CLICK DATASET AT THIS DEPLOYMENT. IT SHOULD BE USED WHEN ACCOUNTING FOR RECORDING EFFORT, SINCE THE CLICK DETECTOR IS OFF-EFFORT DURING SHIP PASSAGES.***';
p.objectives = 'Identify periods of ship presence in passive acoustic recordings to properly account for recording effort in the co-located sperm whale click detection dataset for this deployment.';

%% region-specific settings

duplicateFilesToSkip = {}; % filenames verified as exact duplicates of another file in the same site folder -- set per-region below if needed
fileDeploymentOverrides = containers.Map(); % filename -> cell array of struct('project',...,'id',...): the exact deployment(s) this file's data belongs to, for files whose deployment can't be found (or can't be uniquely found) via the normal project/site/number lookup. Most files map to one deployment; a file can list more than one if its data spans a deployment boundary. Matched by exact deployment ID rather than number, since number alone isn't always unique (e.g. HAT's numbering restarts between its "A" and "B" recording eras) -- set per-region below if needed

switch region

    case 'GofAK'

        projectDir = 'I:\GofAK_TPWS_metadataReduced\ShipTimes'; % folder containing one subfolder per site
        xmlDir = 'I:\GofAK_TPWS_metadataReduced\Tethys\XMLs'; % where to save each deployment's XML

        nonSiteFolders = {}; % no known regional rollups/summaries under GofAK's ShipTimes folder

        % site abbreviations aren't unique across projects, so most GofAK
        % sites need Project+Site to disambiguate. BD was recorded under
        % the Aleut project; QN under GofAK.
        knownProjects = {'GofAK','Aleut'}; % tried in order, together with a Site filter
        siteProjectMap = containers.Map(); % empty: no GofAK ship site needs a Project-only lookup

    case 'CentralPac'

        projectDir = 'I:\CentralPac_TPWS_metadataReduced\ShipTimes'; % folder containing one subfolder per site
        xmlDir = 'I:\CentralPac_TPWS_metadataReduced\Tethys\XMLs'; % where to save each deployment's XML

        nonSiteFolders = {}; % no known regional rollups/summaries under CentralPac's ShipTimes folder

        % unlike GofAK, Central Pacific sites each have their own
        % dedicated Tethys Project, so Project alone (no Site filter)
        % already isolates the right deployments
        knownProjects = {}; % no site here needs a Project+Site fallback
        siteProjectMap = containers.Map({'Kauai','Kona'},{'Kauai','Hawaii'});

    case 'CCE'

        projectDir = 'I:\CCE_TPWS_metadataReduced\ShipTimes'; % folder containing one subfolder per site
        xmlDir = 'I:\CCE_TPWS_metadataReduced\Tethys\XMLs'; % where to save each deployment's XML

        nonSiteFolders = {'All_Sites','PS_Old'}; % All_Sites: regional rollup. PS_Old: legacy duplicate combining PS1+PS2's files

        % every CCE site has its own dedicated Project(+Site) combo -- a
        % {Project,Site} pair filters by both; a plain string is Project only
        knownProjects = {}; % no site here needs a Project+Site fallback
        siteProjectMap = containers.Map( ...
            {'CA','CCE','CORC','DCPP01C','GI','HOKE','PS1','PS2','QC'}, ...
            {{'GofCA','CB'},{'CCE1','SB'},{'OTSG','CORC4'},{'DCPP','C'},{'Baja','GI'},'HOKE',{'PS','PS1'},{'PS','PS1'},{'OCNMS','QC'}});

        % verified byte-identical (isequal) duplicates of a more fully-named
        % file already covering the same deployment in the same folder
        duplicateFilesToSkip = {'CCE01.mat','GI01.mat','GI02.mat'};

        % PS2's recording continued past PS13 but was re-registered in Tethys
        % under a different Project/Site with its own numbering restarting at
        % 1, so these two files don't match anything under Project PS, Site PS1
        fileDeploymentOverrides = containers.Map( ...
            {'PS14.mat','PS15.mat'}, ...
            {{struct('project','MB','id','MB03_01')}, {struct('project','MB','id','MB03_02')}});

    case 'WAT'

        projectDir = 'I:\WAT_TPWS_metadataReduced\ShipTimes'; % folder containing one subfolder per site
        xmlDir = 'I:\WAT_TPWS_metadataReduced\Tethys\XMLs'; % where to save each deployment's XML

        % HAT and HAT_A are superseded by HAT_REDO (the reprocessed version,
        % handled via fileDeploymentOverrides below); HAT_B has no ship
        % files yet
        nonSiteFolders = {'HAT','HAT_A','HAT_B'};

        % most WAT sites (BC, BP, BS, GS, HZ, NC, OC, WC) are recorded
        % under the WAT project with a Site filter; JAX and NFC are each
        % their own Tethys project; HAT_REDO's files actually belong to the
        % HAT project (only used as a fallback here -- every HAT_REDO file
        % is matched via fileDeploymentOverrides below instead, since HAT's
        % deployment numbers aren't unique -- see the note there)
        knownProjects = {'WAT'}; % tried with a Site filter for sites not in siteProjectMap
        siteProjectMap = containers.Map({'JAX','NFC','HAT_REDO'},{'JAX','NFC','HAT'});

        % HAT_REDO's filenames (HAT_01.mat..HAT_06.mat) are just sequential
        % file indices, not real Tethys deployment numbers, and HAT's own
        % deployment numbering restarts between its single-channel "A" era
        % and its later "B" era (e.g. number 6 matches both HAT_A_06 and
        % HAT_B_06_01), so these can only be matched by verified timestamp,
        % never by parsing the filename or its number. Verified against each
        % candidate deployment's actual recording window:
        %   HAT_01 -> HAT_A_05        HAT_04 -> HAT_B_03_01
        %   HAT_02 -> HAT_A_06        HAT_06 -> HAT_B_05
        %   HAT_03 -> HAT_B_01_01
        % HAT_05 spans the HAT_B_03_01 -> HAT_B_04_01 boundary (recording
        % continued across that administrative deployment change), so it
        % lists both deployments; the per-detection effort-window clipping
        % below sorts each interval onto the correct side.
        fileDeploymentOverrides = containers.Map( ...
            {'HAT_01.mat','HAT_02.mat','HAT_03.mat','HAT_04.mat','HAT_05.mat','HAT_06.mat'}, ...
            {{struct('project','HAT','id','HAT_A_05')}, ...
             {struct('project','HAT','id','HAT_A_06')}, ...
             {struct('project','HAT','id','HAT_B_01_01')}, ...
             {struct('project','HAT','id','HAT_B_03_01')}, ...
             {struct('project','HAT','id','HAT_B_03_01'), struct('project','HAT','id','HAT_B_04_01')}, ...
             {struct('project','HAT','id','HAT_B_05')}});

    otherwise
        error('Unrecognized region ''%s''. Add a case for it above, or use ''GofAK'', ''CentralPac'', ''CCE'', or ''WAT''.', region)

end

%% connect to Tethys (needed to look up each site's deployment ID(s) and effort window)

q = dbInit('Server','breach.ucsd.edu','Port',9779); % connect to Tethys server
% dbOpenSchemaDescription(q,'Detections'); % open locaize schema (for our reference) % look at all the information!

import nilus.* % import Nilus, this provides Java objects that correspond to XML elements

species = q.QueryTethys(char("lib:completename2tsn(""" + sp + """)")); % get the ITIS species code

if uploadFlag == 1
    fprintf('WARNING: You are about to build XML files for every deployment found and upload them all to Tethys. Have you updated your metadata appropriately? Be sure to check the section above! \n')
    % keyboard % if you have updated your metadata and are truly ready to upload, comment out this line
end

%% loop through each site folder in the region's ShipTimes directory

siteDirs = dir(projectDir);
siteDirs = siteDirs([siteDirs.isdir] & ~ismember({siteDirs.name},[{'.','..'}, nonSiteFolders]));

xmlFilesBuilt = {}; % collect every XML path built below, so they can all be uploaded together at the end

for iSite = 1:numel(siteDirs)

    siteAbrev = siteDirs(iSite).name;
    siteFolder = fullfile(projectDir, siteAbrev);

    shipMats = dir(fullfile(siteFolder,'*.mat'));
    if isempty(shipMats)
        fprintf('Skipping %s: no .mat files found.\n', siteFolder);
        continue
    end

    %% look up this site's deployment(s) from Tethys
    % site abbreviations aren't unique across projects, so a Project must
    % always be specified. If siteProjectMap has an entry for this site,
    % it's used directly -- either just a Project (when Project alone
    % already isolates the right deployments) or a {Project,Site} pair
    % (needed when several sites share one Project). Otherwise, try each
    % of knownProjects together with a Site filter.

    if isKey(siteProjectMap, siteAbrev)
        mapEntry = siteProjectMap(siteAbrev);
        if iscell(mapEntry)
            projectsToTry = mapEntry(1);
            sitesToTry = mapEntry(2);
        else
            projectsToTry = {mapEntry};
            sitesToTry = {''}; % no site filter
        end
    else
        projectsToTry = knownProjects;
        sitesToTry = repmat({siteAbrev}, size(knownProjects));
    end

    deps = [];
    for iProj = 1:numel(projectsToTry)
        try
            if isempty(sitesToTry{iProj})
                depResult = dbGetDeployments(q,'Project',projectsToTry{iProj});
            else
                depResult = dbGetDeployments(q,'Project',projectsToTry{iProj},'Site',sitesToTry{iProj});
            end
            deps = depResult.Deployment; % a non-matching project can return an empty result rather than error, so the failure shows up here
            break
        catch
            deps = [];
            continue
        end
    end
    if isempty(deps)
        error('No Tethys deployments found for site %s under a known project (%s). Check the site abbreviation, or add it to siteProjectMap/knownProjects above.', siteAbrev, strjoin(projectsToTry,', '));
    end

    % some deployment numbers have more than one record (e.g. co-located
    % single-channel + 4ch instruments) -- keep only the non-4ch record
    depNums = arrayfun(@(x) x.DeploymentNumber{1}, deps);
    keepIdx = [];
    for depNum = unique(depNums)
        matchIdx = find(depNums == depNum);
        if numel(matchIdx) > 1
            depIds = arrayfun(@(ix) deps(ix).Id{1}, matchIdx, 'UniformOutput', false);
            nonFourCh = find(~contains(depIds,'C4','IgnoreCase',true));
            if ~isempty(nonFourCh)
                matchIdx = matchIdx(nonFourCh(1));
            else
                matchIdx = matchIdx(1);
            end
        end
        keepIdx(end+1) = matchIdx; %#ok<AGROW>
    end
    deps = deps(keepIdx);
    depNums = depNums(keepIdx);

    %% gather (deployment, ship presence times) associations from every ship .mat file in this site
    % usually one file maps to exactly one deployment, but a file listed in
    % fileDeploymentOverrides can map to more than one (its data spans a
    % deployment boundary), and two different files can legitimately both
    % contribute to the same deployment (e.g. one file covers most of a
    % deployment and another covers just its tail end) -- so every file's
    % data is gathered here first, keyed by deployment, and concatenated
    % when more than one file targets the same deployment. Two DIFFERENT
    % files landing on the same deployment via the normal number-based
    % match (not an explicit override) is still treated as a mistake, since
    % that path has no human-verified intent behind it.

    detsByDeployment = containers.Map('KeyType','char','ValueType','any'); % deployment ID -> struct('dep',depStruct,'times',Nx2 array,'viaOverride',logical)

    for iFile = 1:numel(shipMats)

        if ismember(shipMats(iFile).name, duplicateFilesToSkip)
            fprintf('Skipping %s: verified duplicate of another file already covering this deployment in %s.\n', shipMats(iFile).name, siteFolder);
            continue
        end

        isOverrideFile = isKey(fileDeploymentOverrides, shipMats(iFile).name);

        if isOverrideFile
            % this file's deployment(s) can't be found (or can't be uniquely
            % found) via the normal project/site/number lookup above -- go
            % fetch each one directly by its exact deployment ID. Usually one
            % entry; more than one means this file's data spans a deployment
            % boundary (see fileDeploymentOverrides above for why)
            overrides = fileDeploymentOverrides(shipMats(iFile).name);
            depsToBuild = {}; % a plain cell array, since an override can point to a different Project whose deployment records don't share the same field structure as this site's own deps
            for iOv = 1:numel(overrides)
                ov = overrides{iOv};
                ovResult = dbGetDeployments(q,'Project',ov.project);
                ovDeps = ovResult.Deployment;
                ovIds = arrayfun(@(x) x.Id{1}, ovDeps, 'UniformOutput', false);
                ovIdx = find(strcmp(ovIds, ov.id));
                if isempty(ovIdx)
                    error('%s: override points to deployment %s under Project %s, but no such deployment was found.', shipMats(iFile).name, ov.id, ov.project);
                end
                depsToBuild{end+1} = ovDeps(ovIdx(1)); %#ok<AGROW>
            end
        else
            [~,matName] = fileparts(shipMats(iFile).name);
            fileDepNum = parseDeploymentNumber(matName);

            depIdx = find(depNums == fileDepNum);
            if isempty(depIdx)
                error('%s: could not match to a Tethys deployment number for site %s (found deployment numbers: %s).', shipMats(iFile).name, siteAbrev, mat2str(depNums));
            end
            depsToBuild = {deps(depIdx(1))};
        end

        load(fullfile(shipMats(iFile).folder,shipMats(iFile).name),'times')

        for iDep = 1:numel(depsToBuild)

            dep = depsToBuild{iDep};
            deployment = dep.Id{1};

            if isKey(detsByDeployment, deployment)
                if ~isOverrideFile
                    error('More than one ship .mat file in %s matched deployment %s via the normal number-based lookup. Resolve the ambiguity (rename or remove one), or add an explicit entry to fileDeploymentOverrides if both really do belong to it.', siteFolder, deployment);
                end
                entry = detsByDeployment(deployment);
                entry.times = [entry.times; times];
            else
                entry = struct('dep',dep,'times',times);
            end
            detsByDeployment(deployment) = entry;

        end

        clear times

    end % ship .mat file loop

    %% build and upload one XML per deployment gathered above

    depIds = keys(detsByDeployment);

    for iKey = 1:numel(depIds)

        deployment = depIds{iKey};
        entry = detsByDeployment(deployment);
        dep = entry.dep;
        times = entry.times;

        % round to the nearest second: converting through datenum can
        % otherwise introduce sub-second drift that flips which side of
        % an exact boundary match a bin/segment lands on
        depStart = datetime(round(dep.DeploymentDetails.TimeStamp{1}*spd)/spd,'ConvertFrom','datenum');
        depEnd = datetime(round(dep.RecoveryDetails.TimeStamp{1}*spd)/spd,'ConvertFrom','datenum');

        if ~isempty(times) && (max(times(:,2)) < datenum(depStart) - 1 || min(times(:,1)) > datenum(depEnd) + 1)
            error('%s: ship presence times fall entirely outside declared deployment window (%s to %s). Check that the source file(s) were matched to the right deployment.', deployment, datestr(depStart), datestr(depEnd));
        end

        eff.Start = depStart;
        eff.End = depEnd;
        xml_out = fullfile(xmlDir,[deployment '_Tethys_Ship_' p.initials '.xml']); % path to save Tethys format xml document

        %% build this deployment's XML

        % this method uses Nilus to create an XML document for this
        % deployment; every deployment's XML is built first, then all of
        % them are uploaded to Tethys together at the very end of the script
        % https://tethys.sdsu.edu/documentation/ for more information!

        if uploadFlag == 1

            % create elements
            d = Detections();
            h = Helper();
            m = MarshalXML();

            m.marshal(d); % generate our XML (empty right now)
            h.createRequiredElements(d); % create the required elements for our XML file

            % identifiers
            d.setUserId(p.userid); % the name of the person who processed the data
            d.setId([deployment,'_ship_detections_',p.userid]); % unique ID for this file
            data_source = d.getDataSource();
            data_source.setDeploymentId(deployment); % deployment ID

            % descriptions
            h.createElement(d,'Description');
            description = d.getDescription();
            description.setAbstract(p.abstract);
            description.setMethod(p.methods);
            description.setObjectives(p.objectives);

            % define information about the algorithm
            alg = d.getAlgorithm();
            h.createRequiredElements(alg);
            alg.setSoftware(p.software);
            alg.setMethod(p.algmethod)

            % effort
            effort = d.getEffort();
            h.createRequiredElements(effort);
            effort.setStart(h.timestamp(dbSerialDateToISO8601(eff.Start)));
            effort.setEnd(h.timestamp(dbSerialDateToISO8601(eff.End)));

            % kinds (info about species, call type, granularity)
            kinds = effort.getKind();
            kind = DetectionEffortKind();
            speciestype = SpeciesIDType();
            speciestype.setValue(h.toXsInteger(str2num(species)));
            kind.setSpeciesId(speciestype);
            kind.setCall(ctype);
            params = javaObject('nilus.DetectionEffortKind$Parameters'); % kind.getParameters() was returning empty, so this is my solution to create the java object directly
            params.setSubtype(csubtype)
            kind.setParameters(params)
            granularitytype = GranularityEnumType.fromValue('encounter');
            granularity = GranularityType();
            granularity.setValue(granularitytype);
            kind.setGranularity(granularity);
            kinds.add(kind);
            d.setEffort(effort)

            % create detection field
            on = d.getOnEffort() ;
            detList = on.getDetection();

            fprintf('Beginning to add ship detections for %s. This may take a while, please be patient. \n', deployment)

            % a ship presence interval can straddle the deployment's
            % registered recording start/end (e.g. an encounter already
            % underway when the recorder came online), or fall entirely
            % outside it (e.g. logged after the recorder was recovered) --
            % Tethys rejects any OnEffort detection outside the declared
            % Effort window, so straddling intervals are clipped to it and
            % fully-outside intervals are dropped (they aren't part of this
            % deployment's effort at all)
            effStartNum = datenum(eff.Start);
            effEndNum = datenum(eff.End);
            nClipped = 0;
            nDropped = 0;

            for i = 1:size(times,1) % for each ship presence interval

                if times(i,2) < effStartNum || times(i,1) > effEndNum
                    nDropped = nDropped + 1; % entirely outside the effort window -- doesn't belong to this deployment
                    continue
                end

                det = Detection(); % grab the detection object

                detStart = max(times(i,1), effStartNum);
                detEnd = min(times(i,2), effEndNum);
                if detStart ~= times(i,1) || detEnd ~= times(i,2)
                    nClipped = nClipped + 1;
                end

                det.setStart(h.timestamp(dbSerialDateToISO8601(detStart))) % input start time of this ship presence
                det.setEnd(h.timestamp(dbSerialDateToISO8601(detEnd))) % set end time

                speciestype.setValue(h.toXsInteger(str2num(species))); % set the species type
                det.setSpeciesId(speciestype); % plug that in

                % input call info
                h.createElement(det,'Call'); % create a field for call type
                callList = det.getCall(); % grab the call element
                callList.add(ctype); % specify these are ships
                h.createElement(det,'Parameters');
                detparams = det.getParameters();
                detparams.setSubtype(csubtype); % specify the subtype

                detList.add(det); % add this detection to the list

            end

            if nClipped > 0
                fprintf('Clipped %d of %d ship presence interval(s) to fit within the effort window for %s.\n', nClipped, size(times,1), deployment)
            end
            if nDropped > 0
                fprintf('Dropped %d of %d ship presence interval(s) entirely outside the effort window for %s.\n', nDropped, size(times,1), deployment)
            end

            fprintf('XML document formatted for Tethys saving at: %s\n',xml_out)
            m.marshal(d, xml_out) % save the xml file in your path from above

            xmlFilesBuilt{end+1} = xml_out; %#ok<SAGROW> % upload happens once, after every XML has been built

        end

    end % per-deployment loop

end % site loop

%% upload every XML file that was built
% Tethys's server has a bug in its multi-file import handler (a 500 error
% from an internal pandas AttributeError whenever more than one source is
% submitted at once), so each file is submitted individually here instead
% of passing the whole cell array to dbSubmit in one call. Building still
% happens first, and uploads all happen back-to-back at the end.

if uploadFlag == 1 && ~isempty(xmlFilesBuilt)
    fprintf('All XML files built. Uploading %d file(s) to Tethys now. \n', numel(xmlFilesBuilt))

    % call the same underlying import routine dbSubmit uses, but capture its
    % response instead of just printing it, so failures can be summarized below
    import dbxml.uploader.*
    url = q.getURLString();

    uploadSucceeded = false(numel(xmlFilesBuilt),1);
    for iFile = 1:numel(xmlFilesBuilt)
        fprintf('Uploading %s\n', xmlFilesBuilt{iFile})
        result = dbxml.uploader.Importer.ImportFiles(url, 'Detections', xmlFilesBuilt{iFile}, '', '', false);
        resultStr = char(result);
        fprintf('%s\n', resultStr);
        uploadSucceeded(iFile) = ~contains(resultStr, '<Failure>');
    end

    fprintf('\n%%%% Upload summary: %d of %d file(s) succeeded %%%%\n', sum(uploadSucceeded), numel(xmlFilesBuilt));
    if all(uploadSucceeded)
        fprintf('All deployments uploaded successfully.\n');
    else
        fprintf('The following deployment(s) FAILED to upload:\n');
        failedFiles = xmlFilesBuilt(~uploadSucceeded);
        for iFail = 1:numel(failedFiles)
            fprintf('  %s\n', failedFiles{iFail});
        end
    end
end

function depNum = parseDeploymentNumber(matName)
% ship .mat filenames aren't consistently the same text as the Tethys
% deployment ID (e.g. 'HAT_01' vs 'HAT01-A', 'Hawaii05' vs 'HAWAII05-K'),
% but the deployment NUMBER is always recoverable: strip any disk-range
% suffix (e.g. '_disk01-13', which is a raw data disk range, not a
% deployment number), then the LAST remaining run of digits is the
% deployment number (an earlier run can be part of a site/project
% abbreviation that itself contains a digit, e.g. 'CORC4' or 'CCE1').
nameNoRange = regexprep(matName,'_?disk\d+-\d+','','ignorecase');
digitRuns = regexp(nameNoRange,'\d+','match');
if isempty(digitRuns)
    error('Could not find a deployment number in filename %s.', matName);
end
depNum = str2double(digitRuns{end});
end
