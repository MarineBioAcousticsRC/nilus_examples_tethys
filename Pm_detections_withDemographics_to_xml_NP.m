%% Pm_detections_withDemographics_to_xml_NP.m

% this script was modified from SPICE_odontclick_detections_to_xml_LMB.m

% this version loops through every site folder in a project directory,
% merges click counts (<site>_workspace125.mat) with demographic
% assignments (<site>_Pm_gender_filled.mat), looks up each site's real
% Tethys deployment(s), splits the merged data by deployment, and
% uploads one XML per deployment.

%% edit me!

clear all

region = 'CCE'; % 'GofAK' or 'CentralPac' -- everything below this block is set automatically from this choice

sp = "Physeter macrocephalus"; % species name
unkFlag = 0; % 1 if this is an unidentified BW click type, 0 if you know the species
fourFlag = 0; % 1 if this is a 4ch, 0 if single
ch = 1; % if you have multiple channels, the channel that you processed
p.binDur = 5; % 1 minute
uploadFlag = 1; % 1; % flag for uploading to Tethys, yes (1) or no (0). if you're not Lauren, you need to change these settings!!!
spd = 60*60*24; % seconds in day, for datenum conversion

p.objectives = 'Detect click counts of sperm whales in 5-minute bins and assign demographic categories when possible.';
p.software = '\\Frosty\MBARC_ALL\Training\Detectors\Sperm whale detector and https://drive.google.com/drive/u/1/folders/1I5xtQhhNr5Buk3P8qfnq3H5F1_XKAz3y';
% p.version = 'GitHub commit # acd3e2f6001e34f4e396450f72234b99e9658bb4';
p.algmethod = 'Energy detector tailored for sperm whale echolocation clicks, all detections verified by analyst NP (and others) using DetEdit.';
p.userid = 'nposdaljian'; % person who uploaded the data

% set some params manually since in this case my intern didn't save the
% metadata files, just a screenshot
% NOTE: these are AB's detector params. if other sites used different
% settings, update these per site before uploading their data! (the
% transfer function, below, is looked up automatically per deployment)
p.dBppThreshold = 125;
p.bpRanges = [5, 95];
p.lockout_time_ms = 30;
p.overlap = 50;
p.sample_ms = 4;

%% region-specific settings

switch region

    case 'GofAK'

        projectDir = 'I:\GofAK_TPWS_metadataReduced\SeasonalityAnalysis'; % folder containing one subfolder per site
        xmlDir = 'I:\GofAK_TPWS_metadataReduced\Tethys\XMLs'; % where to save each deployment's XML

        genderFileSuffix = '_Pm_gender_filled.mat';
        genderVarName = 'binData_mod';

        nonSiteFolders = {'AllSites','BSAI','GOA','MHW_index'}; % known regional rollups/summaries, not real per-site data
        knownEmptyDeployments = {'GOFAK_CB_11','GOFAK_QN01','GOFAK_QN03'}; % confirmed to have no processed detections/effort at all -- not a bug, skip these on purpose

        % site abbreviations aren't unique across projects (e.g. 'CB' also
        % shows up in unrelated Gulf of California deployments), so most
        % GofAK sites need Project+Site to disambiguate. GofAK covers most
        % sites here; BD and KS were recorded under the Aleut project.
        knownProjects = {'GofAK','Aleut'}; % tried in order, together with a Site filter
        siteProjectMap = containers.Map(); % empty: no GofAK site needs a Project-only lookup
        deploymentWindowOverrides = containers.Map(); % empty: no GofAK deployment has known-wrong Tethys dates
        manualDeployments = struct('site',{},'id',{},'start',{},'end',{}); % empty: no GofAK deployment is missing from Tethys
        tfNumberOverrides = containers.Map(); % empty: no GofAK deployment is missing its TF number in the HARP summary
        genderFileOverrides = containers.Map(); % empty: every GofAK site uses the default suffix/varname/scheme above
        deploymentNumberFilter = containers.Map(); % empty: no GofAK site needs to be split by deployment number
        extraDeployments = containers.Map(); % empty: no GofAK site pulls deployments from another Project

        p.methods = 'See manuscript: https://doi.org/10.1371/journal.pone.0285068 and dryad respository: https://doi.org/10.5061/dryad.4tmpg4fg2 for details on methods. ***DISCLAIMER: THIS DATASET HAS A CORRESPONDING DETECTION FILE FOR SHIPS. THIS FILE SHOULD BE USED WHEN ACCOUNTING FOR RECORDING EFFORT SINCE WE ARE OFF EFFORT FOR SPERM WHALES DURING SHIP PASSAGES.***';
        p.abstract = 'Sperm whales exhibit sexual dimorphism and sex-specific latitudinal segregation. Females and their young form social groups and are usually found in temperate and tropical latitudes, while males forage at higher latitudes. Historical whaling data and rare sightings of social groups in high latitude regions of the North Pacific, such as the Gulf of Alaska (GOA) and Bering Sea/Aleutian Islands (BSAI), suggest a more nuanced distribution than previously understood. Sperm whales are the most sighted and recorded cetacean in marine mammal surveys in these regions but capturing their demographic composition and habitat use has proven challenging. This study detects sperm whale presence using passive acoustic data from seven sites in the GOA and BSAI from 2010 to 2019. Differences in click characteristics between males and females (i.e., inter-click and inter-pulse interval) was used as a proxy for animal size/sex to derive time series of animal detections. Generalized additive models with generalized estimation equations demonstrate how spatiotemporal patterns differ between the sexes. Social groups were present at all recording sites with the largest relative proportion at two seamount sites in the GOA and an island site in the BSAI. We found that the seasonal patterns of presence varied for the sexes and between the sites. Male presence was highest in the summer and lowest in the winter, conversely, social group peak presence was in the winter for the BSAI and in the spring for the GOA region, with the lowest presence in the summer months. This study demonstrates that social groups are not restricted to lower latitudes and capture their present-day habitat use in the North Pacific. It highlights that sperm whale distribution is more complex than accounted for in management protocol and underscores the need for improved understanding of sperm whale demographic composition to better understand the impacts of increasing anthropogenic threats, particularly climate change.';

    case 'CentralPac'

        projectDir = 'I:\CentralPac_TPWS_metadataReduced\SeasonalityAnalysis'; % folder containing one subfolder per site
        xmlDir = 'I:\CentralPac_TPWS_metadataReduced\Tethys\XMLs'; % where to save each deployment's XML

        genderFileSuffix = '_Pm_gender.mat';
        genderVarName = 'binData';

        nonSiteFolders = {'All_Sites'}; % known regional rollup/summary, not real per-site data
        knownEmptyDeployments = {'CSM_A_03', ... % confirmed to have no processed detections/effort at all -- not a bug, skip on purpose
            'HAWAII01-K','HAWAII02-K','HAWAII03-K', ... % Kona/Hawaii: only deployments 5-11, 16-20, 22-23, 26-30 have processed data
            'HAWAII13-K','HAWAII14-K','HAWAII15-K', ...
            'HAWAII_K_25','HAWAII_K_31','HAWAII_K_32','HAWAII_K_33','HAWAII_K_36', ...
            'LSM01-S','LSM02-S', ... % LSM: local data (2009) is the "LSM01-d" deployment, which is NOT registered in Tethys under Project LSM.
            'PHR06-A','PHR_B_13','PHR_B_16', ... % PHR: deployments 6, 13, and 16 confirmed not analyzed. Deployment 7 has no Tethys record at all (numbering gap, PHR jumps 06->08), so it's never attempted.
            'PAGAN_A_02','PAGAN_A_03', ... % Pagan: deployments 2 and 3 confirmed not analyzed.
            'PAL04-WT','PAL09-NS','PAL10-NS', ... % Palmyra: only deployments up through 08 were analyzed.
            'SAIPAN_A_10','SAIPAN_A_11', ... % Saipan: only deployments up through 08 were analyzed (09 has no Tethys record -- numbering gap, jumps 08->10).
            'TINIAN_A_06', ... % Tinian: deployment 06 not analyzed (01 has no Tethys record; numbering starts at 02). Nothing registered past deployment 09.
            'WAKE03-S','WAKE_S_10'}; % Wake: deployment 3 and anything past 8 not analyzed (deployment 9 has no Tethys record -- numbering gap, jumps 08->10).
        % LSM note: LSM01-S and LSM02-S are both real, separate 2007 deployments with no overlapping local data. LSM01-d must be
        % added to Tethys before this site's data can be uploaded; until then it has no valid deployment to attach to.

        % unlike GofAK, most Central Pacific sites each have their own
        % dedicated Tethys Project, so Project alone (no Site filter)
        % already isolates the right deployments
        knownProjects = {}; % no site here needs a Project+Site fallback
        siteProjectMap = containers.Map( ...
            {'CSM','EQ','Kauai','Kona','KR','LSM','PHR','Pagan','Palmyra','Saipan','Tinian','Wake'}, ...
            {'CSM','Equa','Kauai','Hawaii','King','LSM','PHR','Pagan','PAL','Saipan','Tinian','Wake'});

        deploymentWindowOverrides = containers.Map(); % none confirmed correct yet -- see note on LSM below

        % LSM01-d and SAIPAN_A_09 are not yet registered in Tethys at all (see knownEmptyDeployments note above), so they
        % can't be found via the normal Tethys lookup. This builds their XML locally from the known recording windows so
        % they're ready to go once registered, but keeps them out of the upload batch (see buildOnlyDeployments below).
        manualDeployments = struct('site',{'LSM','Saipan'},'id',{'LSM01-d','SAIPAN_A_09'}, ...
            'start',{datenum('18-May-2009 00:00:00'),datenum('12-Jul-2018 00:00:00')}, ...
            'end',{datenum('15-Aug-2009 21:44:59'),datenum('01-Feb-2019 00:00:00')});
        tfNumberOverrides = containers.Map({'LSM01-d','SAIPAN_A_09'},{487,736}); % HARPDataSummary lists both as NULL; confirmed manually
        genderFileOverrides = containers.Map(); % empty: every Central Pacific site uses the default suffix/varname/scheme above
        deploymentNumberFilter = containers.Map(); % empty: no Central Pacific site needs to be split by deployment number
        extraDeployments = containers.Map(); % empty: no Central Pacific site pulls deployments from another Project

        p.methods = 'See dissertation: https://escholarship.org/uc/item/1wv6n833 (Posdaljian, N. 2023, UC San Diego) for details on methods, which follow those described in the manuscript and dryad repository for the Gulf of Alaska/Bering Sea Aleutian Islands study: https://doi.org/10.1371/journal.pone.0285068 and https://doi.org/10.5061/dryad.4tmpg4fg2. ***DISCLAIMER: THIS DATASET HAS A CORRESPONDING DETECTION FILE FOR SHIPS. THIS FILE SHOULD BE USED WHEN ACCOUNTING FOR RECORDING EFFORT SINCE WE ARE OFF EFFORT FOR SPERM WHALES DURING SHIP PASSAGES.***';
        p.abstract = 'Sperm whales exhibit sexual dimorphism and sex-specific latitudinal segregation. Females and their young form social groups and are usually found in temperate and tropical latitudes, while males forage at higher latitudes. This study detects sperm whale presence using passive acoustic data from 11 sites in the Central Pacific, spanning the Northern Mariana Islands, Northwestern Hawaiian Islands, Main Hawaiian Islands, Marcus-Wake Seamount Group, and Northern Line Islands, from 2005 to 2019. Differences in click characteristics between males and females (i.e., inter-click interval) were used as a proxy for animal size/sex to derive time series of animal detections. Social groups were present at all recording sites and were the dominant demographic class in the region, present year-round across all seasons, with mid-size animals and adult males comparatively rare relative to higher-latitude regions of the North Pacific. Demographic composition sometimes varied substantially between nearby sites, such as Kauai and Kona in the Main Hawaiian Islands and Saipan and Tinian in the Northern Mariana Islands, likely reflecting differences in local bathymetry and exposure to open ocean versus more sheltered habitat. This study demonstrates that the Central Pacific serves as important year-round habitat for social groups of sperm whales, in contrast with more seasonal patterns of demographic presence seen at higher latitudes. It underscores the need for improved understanding of sperm whale demographic composition across regions to better assess the impacts of increasing anthropogenic threats, particularly climate change.';

    case 'CCE'

        projectDir = 'I:\CCE_TPWS_metadataReduced\SeasonalityAnalysis'; % folder containing one subfolder per site
        xmlDir = 'I:\CCE_TPWS_metadataReduced\Tethys\XMLs'; % where to save each deployment's XML

        genderFileSuffix = '_Pm_gender_filled.mat'; % default; CA/CCE/QC/PS2 override this below (see genderFileOverrides)
        genderVarName = 'binData_mod';

        nonSiteFolders = {'All_Sites','PS_Old'}; % All_Sites: regional rollup. PS_Old: legacy duplicate of PS1 (its workspace file is literally named PS_workspace125.mat, not PS_Old_*)
        knownEmptyDeployments = {'BAJA_GI_04','BAJA_GI_05','BAJA_GI_06', ... % GI: only deployments up through 3 were analyzed.
            'OCNMS02-QC','OCNMS03-QC','OCNMS04-QC','OCNMS05-QC','OCNMS16-QC'}; % QC: only deployments 6 and 12-15 were analyzed (13 has no Tethys record -- numbering gap).

        % every CCE site has its own dedicated Project+Site combo
        knownProjects = {}; % no site here needs a Project+Site fallback
        siteProjectMap = containers.Map( ...
            {'CA','CCE','CORC','DCPP01C','GI','HOKE','PS1','PS2','QC'}, ...
            {{'GofCA','CB'},{'CCE1','SB'},{'OTSG','CORC4'},{'DCPP','C'},{'Baja','GI'},'HOKE',{'PS','PS1'},{'PS','PS1'},{'OCNMS','QC'}});

        deploymentWindowOverrides = containers.Map(); % none confirmed wrong yet
        manualDeployments = struct('site',{},'id',{},'start',{},'end',{}); % none confirmed missing from Tethys yet
        tfNumberOverrides = containers.Map({'OTSG_CORC4_02'},{724}); % HARP summary lists this deployment as "OTSG02_CORC4", not "OTSG_CORC4_02"

        % CA, CCE, and QC's gender files only have the older Female/Juvenile/Male scheme (no _filled version exists at
        % all); PS2 has the newer SocialGroup/MidSize/Male scheme already, but only in the plain (non-_filled) file
        genderFileOverrides = containers.Map( ...
            {'CA','CCE','QC','PS2'}, ...
            {struct('suffix','_Pm_gender.mat','varName','binData','convertScheme',true), ...
             struct('suffix','_Pm_gender.mat','varName','binData','convertScheme',true), ...
             struct('suffix','_Pm_gender.mat','varName','binData','convertScheme',true), ...
             struct('suffix','_Pm_gender.mat','varName','binData','convertScheme',false)});

        % PS1 and PS2 are two different instruments recorded at the same Tethys site (Project PS, Site PS1) during
        % overlapping time periods, so each folder only covers some of that site's deployment numbers. PS2 also
        % continues into two deployments registered under a different project entirely (Project MB, Site MB03).
        deploymentNumberFilter = containers.Map( ...
            {'PS1','PS2'}, ...
            {[1 2 3 4 12 13],[5 6 7 8 9 11]});
        extraDeployments = containers.Map( ...
            {'PS2'}, ...
            {struct('project','MB','site','MB03','depNums',[1 2])});

        p.methods = 'See dissertation: https://escholarship.org/uc/item/1wv6n833 (Posdaljian, N. 2023, UC San Diego) for details on methods, which follow those described in the manuscript and dryad repository for the Gulf of Alaska/Bering Sea Aleutian Islands study: https://doi.org/10.1371/journal.pone.0285068 and https://doi.org/10.5061/dryad.4tmpg4fg2. ***DISCLAIMER: THIS DATASET HAS A CORRESPONDING DETECTION FILE FOR SHIPS. THIS FILE SHOULD BE USED WHEN ACCOUNTING FOR RECORDING EFFORT SINCE WE ARE OFF EFFORT FOR SPERM WHALES DURING SHIP PASSAGES.***';
        p.abstract = 'Sperm whales exhibit sexual dimorphism and sex-specific latitudinal segregation. Females and their young form social groups and are usually found in temperate and tropical latitudes, while males forage at higher latitudes. This study detects sperm whale presence using passive acoustic data from nine sites in the California Current Ecosystem, spanning Quinault Canyon in the north to Guadalupe Island and the Gulf of California in the south, from 2005 to 2022. Differences in click characteristics between males and females (i.e., inter-click interval) were used as a proxy for animal size/sex to derive time series of animal detections. Unlike the Central Pacific, where social groups dominate year-round, demographic composition in the California Current Ecosystem was more evenly split among social groups, mid-size animals, and adult males, consistent with the region serving as both nursery and foraging habitat. Social group presence peaked in the fall, particularly at the southern sites, while mid-size animals and adult males were more prevalent in fall and winter, contrasting with the spring/summer peaks seen in the Eastern North Pacific. Site pairs in close proximity, such as the two Point Sur recording locations, showed markedly different demographic compositions linked to local bathymetry, underscoring fine-scale habitat partitioning within the region. This study demonstrates that the California Current Ecosystem supports a demographically diverse sperm whale population year-round, with local oceanographic features shaping which classes of animals use specific habitats. It underscores the need for improved understanding of sperm whale demographic composition across regions to better assess the impacts of increasing anthropogenic threats, particularly climate change.';

    case 'WAT'

        projectDir = 'I:\WAT_TPWS_metadataReduced\SeasonalityAnalysis'; % folder containing one subfolder per site
        xmlDir = 'I:\WAT_TPWS_metadataReduced\Tethys\XMLs'; % where to save each deployment's XML

        genderFileSuffix = '_Pm_gender_filled.mat';
        genderVarName = 'binData_mod';

        nonSiteFolders = {'AllSites','North','South','HAT'}; % AllSites/North/South: regional rollups. HAT: pooled HAT_A+HAT_B rollup, not a standalone deployment
        knownEmptyDeployments = {'HAT01-A','HAT02-A','HAT03-A','HAT04-A', ... % HAT_A: only deployments 5 and 6 were analyzed.
            'HAT_B_02_03_C4','HAT_B_06_01','HAT_B_07','HAT_B_08', ... % HAT_B: only deployments 1, 3, 4, and 5 were analyzed.
            'NFC01-A','NFC_A_05','NFC_A_06', ... % NFC: only deployments 2, 3, and 4 were analyzed.
            'JAX11-D','JAX_D_12','JAX_D_16'}; % JAX/D: only deployments 13, 14, and 15 were analyzed.

        % most WAT sites share Project WAT (disambiguated by Site); HAT_A/HAT_B and NFC each have their own dedicated Project
        knownProjects = {}; % no site here needs a Project+Site fallback
        siteProjectMap = containers.Map( ...
            {'BC','BP','BS','GS','HZ','JAX','NC','OC','WC','NFC','HAT_A','HAT_B'}, ...
            {{'WAT','BC'},{'WAT','BP'},{'WAT','BS'},{'WAT','GS'},{'WAT','HZ'},{'JAX','D'},{'WAT','NC'},{'WAT','OC'},{'WAT','WC'},{'NFC','A'},{'HAT','A'},{'HAT','B'}});

        deploymentWindowOverrides = containers.Map(); % none confirmed wrong yet
        manualDeployments = struct('site',{},'id',{},'start',{},'end',{}); % none confirmed missing from Tethys yet
        tfNumberOverrides = containers.Map(); % none confirmed missing from the HARP summary yet
        genderFileOverrides = containers.Map(); % empty: every WAT site uses the default suffix/varname/scheme above
        deploymentNumberFilter = containers.Map(); % empty: no WAT site needs to be split by deployment number
        extraDeployments = containers.Map(); % empty: no WAT site pulls deployments from another Project

        p.methods = 'See dissertation: https://escholarship.org/uc/item/1wv6n833 (Posdaljian, N. 2023, UC San Diego) for details on methods, which follow those described in the manuscript and dryad repository for the Gulf of Alaska/Bering Sea Aleutian Islands study: https://doi.org/10.1371/journal.pone.0285068 and https://doi.org/10.5061/dryad.4tmpg4fg2. ***DISCLAIMER: THIS DATASET HAS A CORRESPONDING DETECTION FILE FOR SHIPS. THIS FILE SHOULD BE USED WHEN ACCOUNTING FOR RECORDING EFFORT SINCE WE ARE OFF EFFORT FOR SPERM WHALES DURING SHIP PASSAGES.***';
        p.abstract = 'Sperm whales exhibit sexual dimorphism and sex-specific latitudinal segregation. Females and their young form social groups and are usually found in temperate and tropical latitudes, while males forage at higher latitudes. This study detects sperm whale presence using passive acoustic data from 12 sites along a latitudinal gradient in the western North Atlantic, from Gulf Stream-adjacent submarine canyons of the Mid-Atlantic Bight and Georges Bank in the north to the South-Atlantic Bight in the south, from 2015 to 2019. Differences in click characteristics between males and females (i.e., inter-click interval) were used as a proxy for animal size/sex to derive time series of animal detections. Social groups were the dominant demographic class at nearly all sites, comprising over 80% of estimated acoustic density, followed by mid-size animals, with adult males comparatively rare. Sperm whale presence was significantly higher north of the Gulf Stream, with peaks in spring and summer, while presence south of the Gulf Stream peaked in fall and winter. Acoustic density of social groups increased substantially at the northernmost sites over the study period, suggesting a possible northward range expansion or population recovery linked to changing oceanographic conditions. This study demonstrates that the western North Atlantic continental slope is important year-round habitat for social groups of sperm whales, with demographic composition and seasonal presence varying markedly along the latitudinal gradient. It underscores the need for improved understanding of sperm whale demographic composition across regions to better assess the impacts of increasing anthropogenic threats, particularly climate change.';

    otherwise
        error('Unrecognized region ''%s''. Add a case for it above, or use ''GofAK'', ''CentralPac'', ''CCE'', or ''WAT''.', region)

end

buildOnlyDeployments = {manualDeployments.id}; % manual deployments aren't registered/verified in Tethys yet, so build their XML but never add it to the upload batch

harpSummaryFile = fullfile(fileparts(mfilename('fullpath')),'HARPDataSummary_20240618.xlsx'); % HARP Data Summary, column 3 (TF number) drives the transfer function lookup below
tfBaseDir = 'L:\Shared drives\MBARC_TF'; % always use the "B" revision .tf file for a given TF number

harpSummary = readtable(harpSummaryFile,'VariableNamingRule','preserve');

%% connect to Tethys (needed to look up each site's deployment ID(s) and effort window)

q = dbInit('Server','breach.ucsd.edu','Port',9779); % connect to Tethys server
% dbOpenSchemaDescription(q,'Detections'); % open locaize schema (for our reference) % look at all the information!

import nilus.* % import Nilus, this provides Java objects that correspond to XML elements

if unkFlag == 0 % if we know the species
    species = q.QueryTethys(char("lib:completename2tsn(""" + sp + """)")); % get the ITIS species code
elseif unkFlag == 1 % if this is an unidentified species
    species = q.QueryTethys(char("lib:completename2tsn(""Hyperoodontidae"")")); % get the ITIS species code
end

if uploadFlag == 1
    fprintf('WARNING: You are about to build XML files for every deployment found and upload them all to Tethys. Have you updated your metadata appropriately? Be sure to check the section above! \n')
    % keyboard % if you have updated your metadata and are truly ready to upload, comment out this line
end

%% loop through each site folder in the project directory

siteDirs = dir(projectDir);
siteDirs = siteDirs([siteDirs.isdir] & ~ismember({siteDirs.name},[{'.','..'}, nonSiteFolders]));

xmlFilesBuilt = {}; % collect every XML path built below, so they can all be uploaded together at the end

for iSite = 1:numel(siteDirs)

    siteAbrev = siteDirs(iSite).name;
    siteFolder = fullfile(projectDir, siteAbrev);

    % most sites use the region's default gender file suffix/variable name, but a few
    % sites only have the older Female/Juvenile/Male scheme instead of SocialGroup/
    % MidSize/Male (see genderFileOverrides above)
    if isKey(genderFileOverrides, siteAbrev)
        thisGenderSuffix = genderFileOverrides(siteAbrev).suffix;
        thisGenderVarName = genderFileOverrides(siteAbrev).varName;
        convertGenderScheme = genderFileOverrides(siteAbrev).convertScheme;
    else
        thisGenderSuffix = genderFileSuffix;
        thisGenderVarName = genderVarName;
        convertGenderScheme = false;
    end

    genderFile = dir(fullfile(siteFolder,[siteAbrev thisGenderSuffix]));
    workFile = dir(fullfile(siteFolder,[siteAbrev '_workspace125.mat']));

    if isempty(genderFile) || isempty(workFile)
        error('%s is missing %s%s or %s_workspace125.mat. If this is actually not a real site folder, add it to nonSiteFolders above.', siteAbrev, siteAbrev, thisGenderSuffix, siteAbrev);
    end

    %% merge click counts (binData) with demographic assignments (binData_mod/binData)

    sGender = load(fullfile(genderFile.folder,genderFile.name),thisGenderVarName);
    sWork = load(fullfile(workFile.folder,workFile.name),'binData','Start','End');

    binDataMod = sGender.(thisGenderVarName);

    if convertGenderScheme
        % this site's demographic classification hasn't been redone with the newer
        % SocialGroup/MidSize/Male scheme yet -- map the older Female/Juvenile/Male
        % columns onto it (Male is already the same column in both schemes)
        binDataMod.SocialGroup = binDataMod.Female;
        binDataMod.MidSize = binDataMod.Juvenile;
    end

    binData_all = sWork.binData(:,{'Count'}); % keep tbin (row times) and Count from binData
    binData_all.SocialGroup = zeros(height(binData_all),1);
    binData_all.MidSize = zeros(height(binData_all),1);
    binData_all.Male = zeros(height(binData_all),1);

    [tf,loc] = ismember(binData_all.tbin, binDataMod.tbin); % bins with no match in binData_mod keep the zeros set above
    binData_all.SocialGroup(tf) = binDataMod.SocialGroup(loc(tf));
    binData_all.MidSize(tf) = binDataMod.MidSize(loc(tf));
    binData_all.Male(tf) = binDataMod.Male(loc(tf));

    % some matched bins are unclassified (NaN) rather than 0 in the source file --
    % treat those the same as unmatched bins (i.e. not assigned to that class)
    binData_all.SocialGroup(isnan(binData_all.SocialGroup)) = 0;
    binData_all.MidSize(isnan(binData_all.MidSize)) = 0;
    binData_all.Male(isnan(binData_all.Male)) = 0;

    %% look up this site's deployment(s) from Tethys
    % site abbreviations aren't unique across projects (e.g. GofAK's 'CB'
    % also matches unrelated Gulf of California deployments), so a
    % Project must always be specified. If siteProjectMap has an entry for
    % this site, it's used directly -- either just a Project (when Project
    % alone already isolates the right deployments, true for most Central
    % Pacific/CCE sites) or a {Project,Site} pair (needed when several
    % sites share one Project, e.g. most of WAT). Otherwise, try each of
    % knownProjects together with a Site filter (needed for GofAK, where
    % several sites share one Project and there's no per-site map entry).

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

    % restrict to specific deployment numbers when this site only covers part of
    % what Tethys returns (e.g. CCE's PS1 and PS2 folders both map to Tethys site
    % PS1, split by deployment number -- see deploymentNumberFilter above)
    if isKey(deploymentNumberFilter, siteAbrev)
        depNums = arrayfun(@(x) x.DeploymentNumber{1}, deps);
        deps = deps(ismember(depNums, deploymentNumberFilter(siteAbrev)));
    end

    % merge in deployments from a different Project/Site entirely (e.g. CCE's PS2
    % folder also covers two deployments registered under Project MB, Site MB03 --
    % see extraDeployments above)
    if isKey(extraDeployments, siteAbrev)
        for extra = extraDeployments(siteAbrev)
            exResult = dbGetDeployments(q,'Project',extra.project,'Site',extra.site);
            exDeps = exResult.Deployment;
            exDepNums = arrayfun(@(x) x.DeploymentNumber{1}, exDeps);
            exDeps = exDeps(ismember(exDepNums, extra.depNums));
            % different projects' deployment records don't always have the same set
            % of fields (e.g. an optional Cruise field), so keep only fields common
            % to both sides before concatenating
            commonFields = intersect(fieldnames(deps), fieldnames(exDeps));
            deps = orderfields(rmfield(deps, setdiff(fieldnames(deps), commonFields)));
            exDeps = orderfields(rmfield(exDeps, setdiff(fieldnames(exDeps), commonFields)));
            deps = [deps, exDeps]; %#ok<AGROW>
        end
    end

    % some deployment numbers have more than one record (e.g. co-located
    % single-channel + 4ch instruments, sometimes more than one 4ch record for
    % the same period) -- prefer non-4ch records, then among whatever's left,
    % keep the one that covers the longest span (the other records are shorter
    % overlapping sub-periods from an instrument that stopped early)
    depNums = arrayfun(@(x) x.DeploymentNumber{1}, deps);
    keepIdx = [];
    for depNum = unique(depNums)
        matchIdx = find(depNums == depNum);
        if numel(matchIdx) > 1
            depIds = arrayfun(@(ix) deps(ix).Id{1}, matchIdx, 'UniformOutput', false);
            nonFourCh = find(~contains(depIds,'C4','IgnoreCase',true));
            if ~isempty(nonFourCh)
                matchIdx = matchIdx(nonFourCh);
            end
            if numel(matchIdx) > 1
                durations = arrayfun(@(ix) deps(ix).RecoveryDetails.TimeStamp{1} - deps(ix).DeploymentDetails.TimeStamp{1}, matchIdx);
                [~,longestIdx] = max(durations);
                matchIdx = matchIdx(longestIdx);
            end
        end
        keepIdx(end+1) = matchIdx; %#ok<AGROW>
    end
    deps = deps(keepIdx);

    % add any manual deployments for this site (not yet registered in Tethys -- see manualDeployments above)
    for iManual = find(strcmpi({manualDeployments.site}, siteAbrev))
        synthDep = deps(1); % template: copy field structure/types from a real deployment record
        synthDep.Id = {manualDeployments(iManual).id};
        synthDep.DeploymentDetails.TimeStamp = {manualDeployments(iManual).start};
        synthDep.RecoveryDetails.TimeStamp = {manualDeployments(iManual).end};
        deps(end+1) = synthDep; %#ok<AGROW>
    end

    %% build and upload one XML per deployment

    for iDep = 1:numel(deps)

        dep = deps(iDep);

        if ismember(dep.Id{1}, knownEmptyDeployments)
            fprintf('Skipping %s: confirmed to have no processed detections/effort (see knownEmptyDeployments).\n', dep.Id{1});
            continue
        end

        if isKey(deploymentWindowOverrides, dep.Id{1})
            % this deployment's Tethys dates are known to be wrong --
            % use the corrected window instead
            overrideWindow = deploymentWindowOverrides(dep.Id{1});
            depStart = overrideWindow(1);
            depEnd = overrideWindow(2);
        else
            % round to the nearest second: converting through datenum can
            % otherwise introduce sub-second drift that flips which side of
            % an exact boundary match a bin/segment lands on
            depStart = datetime(round(dep.DeploymentDetails.TimeStamp{1}*spd)/spd,'ConvertFrom','datenum');
            depEnd = datetime(round(dep.RecoveryDetails.TimeStamp{1}*spd)/spd,'ConvertFrom','datenum');
        end

        % assign each 5-min bin to the deployment whose declared window
        % contains it. recording can run continuously across an
        % administrative deployment boundary, so this must be done per
        % bin rather than by bulk-assigning whole effort segments by
        % their start time (a segment can span more than one deployment)
        binData = binData_all(binData_all.tbin >= depStart & binData_all.tbin <= depEnd, :);

        % effort segments that overlap this deployment's window at all;
        % clip to the declared window since a segment can start before
        % or run past it
        segIdx = sWork.Start <= depEnd & sWork.End >= depStart;

        if height(binData) == 0 || ~any(segIdx)
            error('No detections/effort found for %s (declared window %s to %s). Inspect binData_all, sWork, depStart, and depEnd to see why.', dep.Id{1}, datestr(depStart), datestr(depEnd));
        end

        deployment = dep.Id{1};
        eff.Start = max(depStart, min(sWork.Start(segIdx))); % actual recorded effort start for this deployment
        eff.End = min(depEnd, max(sWork.End(segIdx))); % actual recorded effort end for this deployment

        % a bin's label can fall a few minutes before/after the clipped effort
        % window even though it passed the broader depStart/depEnd filter above
        % (e.g. a 5-min bin starting just before effort technically began) --
        % Tethys rejects any detection outside of Effort, so drop those bins here
        binData = binData(binData.tbin >= eff.Start & binData.tbin <= eff.End, :);
        if height(binData) == 0
            error('No detections remain for %s after clipping to the actual effort window (%s to %s). Inspect binData_all, sWork, eff.Start, and eff.End to see why.', deployment, datestr(eff.Start), datestr(eff.End));
        end

        xml_out = fullfile(xmlDir,[deployment '_Tethys_Pm_NP.xml']); % path to save Tethys format xml document

        % look up this deployment's transfer function from the HARP data summary
        % (unless it's been manually confirmed via tfNumberOverrides, e.g. because
        % the HARP summary has it listed as NULL)
        if isKey(tfNumberOverrides, deployment)
            tfNum = tfNumberOverrides(deployment);
        else
            harpRow = find(strcmpi(harpSummary.Var1, deployment));
            if isempty(harpRow) || isnan(harpSummary.Var3(harpRow(1)))
                error('No transfer function number found for %s in the HARP data summary.', deployment);
            end
            tfNum = harpSummary.Var3(harpRow(1));
        end
        p.tfFullFile = findTfFile(tfBaseDir, tfNum);
        if isempty(p.tfFullFile)
            error('Could not find a "B" revision .tf file for %s (TF number %d).', deployment, tfNum);
        end

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
            d.setId([deployment,'_Pm_detections_',p.userid]); % unique ID for this file
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
            % alg.setVersion(p.version);
            alg.setMethod(p.algmethod)

            % add in some more specific info from detection
            h.createElement(alg,'Parameters')
            algparm = alg.getParameters();
            algparmList = algparm.getAny();
            h.AddAnyElement(algparmList,'dbPP_threshold',num2str(p.dBppThreshold));
            h.AddAnyElement(algparmList,'bandpass_lowerEdge_kHz',num2str(p.bpRanges(1)));
            h.AddAnyElement(algparmList,'bandpass_upperEdge_kHz',num2str(p.bpRanges(2)));
            h.AddAnyElement(algparmList,'tf_path',p.tfFullFile);
            h.AddAnyElement(algparmList,'lockout_time_ms',num2str(p.lockout_time_ms));
            h.AddAnyElement(algparmList,'overlap',num2str(p.overlap));
            h.AddAnyElement(algparmList,'sample_ms',num2str(p.sample_ms));

            % effort
            effort = d.getEffort();
            h.createRequiredElements(effort);
            effort.setStart(h.timestamp(dbSerialDateToISO8601(eff.Start)));
            effort.setEnd(h.timestamp(dbSerialDateToISO8601(eff.End)));

            % kinds (info about species, call type, granularity
            kinds = effort.getKind();
            kind = DetectionEffortKind();
            speciestype = SpeciesIDType();
            speciestype.setValue(h.toXsInteger(str2num(species)));
            if unkFlag == 1
                speciestype.setGroup(sp);
            end
            kind.setSpeciesId(speciestype);
            kind.setCall('Clicks');
            granularitytype = GranularityEnumType.fromValue('binned');
            granularity = GranularityType();
            granularity.setValue(granularitytype);
            kind.setGranularity(granularity);
            kinds.add(kind);
            granularity.setBinSizeMin(java.lang.Double(p.binDur));
            granularity.setFirstBinStart(h.timestamp(dbSerialDateToISO8601(binData.tbin(1))))
            d.setEffort(effort)

            % create detection field
            on = d.getOnEffort() ;
            detList = on.getDetection();

            fprintf('Beginning to add detections for %s. This may take a while, please be patient. \n', deployment)

            for i = 1:height(binData) % for each bin

                det = Detection();

                det.setStart(h.timestamp(dbSerialDateToISO8601(binData.tbin(i)))) % input start time of this bin

                % % UPLOAD THE FILE THAT HAS EFFORT SECONDS FOR EACH 5 MIN BIN % %
                % det.setEnd(h.timestamp(dbSerialDateToISO8601(binData.tbin(i) + (binData.Effort_seconds(i)/spd)))) % set end time, useful because sometimes we have partial effort
                speciestype.setValue(h.toXsInteger(str2num(species))); % set the species type
                det.setSpeciesId(speciestype); % plug that in
                det.setCount(h.toXsInteger(binData.Count(i))) % set the number of clicks per bin

                h.createElement(det,'Call'); % create a field for call type
                callList = det.getCall(); % grab the call element
                callList.add('Clicks'); % specify these are clicks

                if fourFlag == 1
                    h.createElement(det,'Channel'); % create field for channel number
                    det.setChannel(h.toXsInteger(ch))
                end

                % add a parameter for bin effort so we don't need to recalcualte it
                % every time (future me will be happy :)
                h.createElement(det,'Parameters');
                params = det.getParameters();
                h.createElement(params,'UserDefined');
                userdef = params.getUserDefined();
                userdefList = userdef.getAny();

                if binData.SocialGroup(i)
                    h.AddAnyElement(userdefList,'Demographics','SocialGroup');
                end

                if binData.MidSize(i)
                    h.AddAnyElement(userdefList,'Demographics','MidSize');
                end

                if binData.Male(i)
                    h.AddAnyElement(userdefList,'Demographics','Male');
                end

                if ~binData.SocialGroup(i) &&  ~binData.MidSize(i) && ~ binData.Male(i)
                    h.AddAnyElement(userdefList,'Demographics','Not Assigned');
                end

                detList.add(det);

            end

            fprintf('XML document formatted for Tethys saving at: %s\n',xml_out)
            m.marshal(d, xml_out) % save the xml file in your path from above

            if ismember(deployment, buildOnlyDeployments)
                fprintf('%s is not yet registered in Tethys -- built locally but NOT added to the upload batch.\n', deployment);
            else
                xmlFilesBuilt{end+1} = xml_out; %#ok<SAGROW> % upload happens once, after every XML has been built
            end

        end

    end % deployment loop

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
        result = dbxml.uploader.Importer.ImportFiles(url, 'Detections', xmlFilesBuilt{iFile}, '', '', true); % overwrite: safe to resubmit already-uploaded deployments with identical content
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

function tfPath = findTfFile(tfBaseDir, tfNum)
% search the numeric-range subfolders of tfBaseDir (e.g. '600-699') for a
% folder named after tfNum, then return its "B" revision .tf file -- falling
% back to the "A" revision if no "B" revision exists for that TF number
tfPath = '';
tfNumStr = num2str(tfNum);
rangeDirs = dir(tfBaseDir);
rangeDirs = rangeDirs([rangeDirs.isdir] & ~ismember({rangeDirs.name},{'.','..'}));
for k = 1:numel(rangeDirs)
    candidateFolder = fullfile(rangeDirs(k).folder, rangeDirs(k).name, tfNumStr);
    if isfolder(candidateFolder)
        tfFileInfo = dir(fullfile(candidateFolder,[tfNumStr '_*_B_*.tf']));
        if isempty(tfFileInfo)
            tfFileInfo = dir(fullfile(candidateFolder,[tfNumStr '_*_A_*.tf']));
        end
        if ~isempty(tfFileInfo)
            tfPath = fullfile(tfFileInfo(1).folder, tfFileInfo(1).name);
        end
        return
    end
end
end
