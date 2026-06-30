% upload_tracks_Tethys

% Lauren and Marie 3/10/25 in MATLAB 2023a
% upload WheresWhaledo tracks to Tethys using Nilus

%% first, create ensembles for the 4ch deployments

xml_out = 'F:\Baggett_2025_Zc_Tracking\Tracking\tethys_upload\ensembles\SOCAL_N_68_ensemble.xml'; % path to save ensemble xml file

q=dbInit('Server','breach.ucsd.edu','Port',9779);
% dbOpenSchemaDescription(q,'Ensemble'); % open localize schema (for our reference)
import nilus.* % import Nilus, this provides Java objects that correspond to XML elements

% create elements
e = Ensemble();
h = Helper();
m = MarshalXML();
h.createRequiredElements(e)

% set ensemble ID
e.setId('SOCAL_N_68_ensemble') % set the ensemble ID name for this deployment

% set units (associate this unit with an actual deployment)
h.createElement(e,'Unit')
un = e.getUnit();
u = UnitGroup();
u.setUnitId(h.toXsInteger(1))
u.setDeploymentId('SOCAL_N_68_NS_C4')
un.add(u)
u = UnitGroup();
u.setUnitId(h.toXsInteger(2))
u.setDeploymentId('SOCAL_N_68_NW_C4')
un.add(u)

% set zero position
load('C:\Users\Lauren\Documents\GitHub\Wheres-Whaledo\ww\instrument_orientation\precalculated_ensembles\SOCAL_N_68\SOCAL_N_68_NS_harp4chParams');
hydLoc{1} = recLoc;
load('C:\Users\Lauren\Documents\GitHub\Wheres-Whaledo\ww\instrument_orientation\precalculated_ensembles\SOCAL_N_68\SOCAL_N_68_NW_harp4chParams');
hydLoc{2} = recLoc;
h0 = mean([hydLoc{1}; hydLoc{2}]);
h.createElement(e,'ZeroPosition');
zero = e.getZeroPosition();
zero.setLatitude(h0(1))
zero.setLongitude(h0(2)+360)
zero.setElevationInstrumentM(h.toXsDouble(h0(3))) % in schema, this is called ElevationInstrument_m

% m.marshal(e) % if you want to take a look at it before you upload
m.marshal(e, xml_out) % save the xml file in your path from above
dbSubmit('Server','breach.ucsd.edu','Port',9779) % launch the submission interface

%% now, run for tracks if you already have ensembles defined

% input variables
df = dir('F:\Baggett_2025_Zc_Tracking\Tracking\Erics_detector\SOCAL_N_68\cleaned_tracks\track*'); % path to track files
load('F:\GDrive_Backup\Lauren Baggett MS\AI_Classification\Time_Tables\Zc\SOCAL_N_68\SOCAL_N_68_Zc_encounterTimes.mat')

ens = 'SOCAL_N_68_ensemble';
xmlOutFolder = 'F:\Baggett_2025_Zc_Tracking\Tracking\Erics_detector\SOCAL_N_68\tethys_XML'; % path to save Tethys format xml document
spd = 60*60*24; % seconds in day, for datenum conversion
splatin = 'Ziphius cavirostris'; % the corresponding latin species names for the codes above

% set some params manually
p.fc = 20e3; % highpass filter cutoff frequency, Hz
p.th = 28; % detection threshold (counts)
p.minPkDist = round(5e-3*100000); % min separation between detections (samples)
p.maxdn = 100; % max TDOA (samples)
p.sigDuration = round(580e-6*100000); % expected signal duration (samples)
p.soundSpeed = 1482.3159; % sound speed (m/s)

% input methods/abstract info
p.methods = 'See the publication for full details, Baggett et al., 2025 (https://doi.org/10.1038/s41598-025-24490-x).';
p.abstract = 'The tracks contained in this dataset were processed as a full analysis of Ziphius cavirostris diving behavior at SOCAL tracking sites. These tracks were processed using WheresWhaledo v1.0. Lauren Baggett processed and verified all tracks.';
p.objectives = 'Understand Ziphius cavirostris diving behavior at depth across SOCAL sites. Aggregate spatial and behavioral patterns.';
p.software = 'https://github.com/MarineBioAcousticsRC/Wheres-Whaledo';
p.version = 'Version 1.0';
p.algmethod = 'WheresWhaledo odontocete tracking, all tracks processed and verified by Lauren Baggett.';
p.userid = 'lbaggett'; % person who processed the data

%% start populating xml

% connect to Tethys server
q=dbInit('Server','breach.ucsd.edu','Port',9779);
% dbOpenSchemaDescription(q,'Localize'); % open locaize schema (for our reference)

import nilus.* % import nulis, pg 4

[~,zeroPos] = dbGetEnsembles(q,'Id',ens); % grab the zero position for this ensemble

% create a file for each encounter
for j = 1:height(bwEnc)

    % match the track to this encounter number
    matchIdx = find(strcmp({df.name}, ['track', num2str(bwEnc.encN(j))]));

    if ~isempty(matchIdx) % if we tracked whales in this encounter

        % create our elements
        l = Localize();
        h = Helper();
        m = MarshalXML();

        m.marshal(l); % generate our XML (empty right now)
        h.createRequiredElements(l); % create the required elements

        thisUnqId = [ens,'_',splatin,'_tracks_Baggett_et_al_encounter',num2str(bwEnc.encN(j))];

        l.setUserId(p.userid);
        l.setId(thisUnqId); % unique ID for this file
        l.getDataSource().setEnsembleId(ens); % replace this with real instruments
        % m.marshal(l)

        % description
        h.createElement(l,'Description');
        description = l.getDescription();
        description.setAbstract(p.abstract);
        description.setMethod(p.methods);
        description.setObjectives(p.objectives);
        % m.marshal(description)

        % algorithm
        alg = l.getAlgorithm();
        h.createRequiredElements(alg);
        alg.setSoftware(p.software);
        alg.setVersion(p.version);
        alg.setMethod(p.methods)

        % add in specific paramters
        h.createElement(alg,'Parameters')
        algparm = alg.getParameters();
        algparmList = algparm.getAny();
        h.AddAnyElement(algparmList,'highpass_cutoff_Hz',num2str(p.fc));
        h.AddAnyElement(algparmList,'detection_threshold_counts',num2str(p.th));
        h.AddAnyElement(algparmList,'signal_duration_samples',num2str(p.sigDuration));
        h.AddAnyElement(algparmList,'max_TDOA_samples',num2str(p.maxdn));
        h.AddAnyElement(algparmList,'min_pk_dist_samples',num2str(p.minPkDist));
        h.AddAnyElement(algparmList,'sound_speed_ms-1',num2str(p.soundSpeed));

        % effort
        effort = l.getEffort();
        h.createRequiredElements(effort)
        effort.setStart(h.timestamp(dbSerialDateToISO8601(bwEnc.startSnipped(j))));
        effort.setEnd(h.timestamp(dbSerialDateToISO8601(bwEnc.endSnipped(j))));
        effort.setTimeReference('relative');
        effort.setDimension(3);
        ltype = effort.getLocalizationType();
        ltype.add('Track');
        % m.marshal(effort)

        % coordinate reference
        crs = effort.getCoordinateReferenceSystem();
        crs.setSubtype('Engineering');
        crs.setName('Cartesian');
        % m.marshal(crs)

        % reference frame
        h.createElement(crs,'ReferenceFrame');
        ref = crs.getReferenceFrame();
        ref.setAnchor('WGS84');
        % can use the helper class to convert this to a double
        ref.setLatitude(h.toXsDouble(zeroPos.Latitude));
        ref.setLongitude(h.toXsDouble(zeroPos.Longitude));
        ref.setElevationM(h.toXsDouble(zeroPos.ElevationInstrument_m));
        % m.marshal(ref)

        % load the tracked data for this encounter
        thisFile = dir([df(matchIdx).folder,'\',df(matchIdx).name,'\*whale.mat']);
        load(fullfile(thisFile.folder,thisFile.name))
        whale = whale(~cellfun('isempty',whale)); % remove empty cells
        keepIdx = cellfun(@(x) ~(istable(x) && any(size(x)==0)), whale);
        whale = whale(keepIdx);

        % retrieve the list of localizations, this will be empty at first
        loc_list = l.getLocalizations().getLocalization();
        % loc_list = l.getLocalizations();

        % loop over the tracks in this encounter
        for wn = 1:numel(whale)

            whale{wn}.TDet = whale{wn}.TDet + datenum([2000 0 0 0 0 0]);

            track = LocalizationType();
            h.createElement(track,'TimeStamp')
            h.createElement(track,'Track')
            h.createElement(track,'SpeciesId')
            t = track.getTrack();
            h.createElement(t,'Cartesian')
            h.createElement(t,'TimeStamps')
            cart = t.getCartesian();
            h.createElement(cart,'Coordinates')
            h.createElement(cart,'CoordinateError')

            % set the first timestamp
            track.setTimeStamp(h.timestamp(dbSerialDateToISO8601(whale{wn}.TDet(1))));
            
            % set species id
            spc = q.QueryTethys(char("lib:completename2tsn(""" + splatin + """)")); % get the ITIS species code
            speciestype = SpeciesIDType();
            speciestype.setValue(h.toXsInteger(str2num(spc)));
            track.setSpeciesId(speciestype)

            % set coordinate bounds        
            bounds = cart.getCoordinateBounds();
            nw = bounds.getNorthWest();
            nw.setXM(min(whale{wn}.wloc(:,1)))
            nw.setYM(max(whale{wn}.wloc(:,2)))
            bounds.setNorthWest(nw)
            se = bounds.getSouthEast();
            se.setXM(max(whale{wn}.wloc(:,1)))
            se.setYM(min(whale{wn}.wloc(:,2)))

            % add timestamps
            ts = t.getTimeStamps();
            for n = 1:height(whale{wn})
                ts.add(h.timestamp(dbSerialDateToISO8601(whale{wn}.TDet(n))));
            end
           
            % create X,Y,Z
            locations = whale{wn}.wloc;
            col = 1;
            c = cart.getCoordinates();
            for field = ["XM", "YM", "ZM"]
                h.createElement(c, field);
                % we want to call c.getXM, c.getYM, etc.
                coord_list = javaMethod(sprintf("get%s", field), c);
                for row = 1:size(locations, 1)
                    coord_list.add(locations(row, col));
                end
                col = col + 1;
            end

            % create X,Y,Z error
            errs = [abs(whale{wn}.CIx(:,1)-whale{wn}.CIx(:,2))/2, abs(whale{wn}.CIy(:,1)-whale{wn}.CIy(:,2))/2, abs(whale{wn}.CIz(:,1)-whale{wn}.CIz(:,2))/2];
            col = 1;
            c = cart.getCoordinateError();
            for field = ["XM", "YM", "ZM"]
                h.createElement(c, field);
                % we want to call c.getXM, c.getYM, etc.
                coord_list = javaMethod(sprintf("get%s", field), c);
                for row = 1:size(errs, 1)
                    coord_list.add(errs(row, col));
                end
                col = col + 1;
            end

            % add this track to the list
            track.setTrack(t)
            loc_list.add(track);
            
        end % move onto the next track

        % m.marshal(l)
        xml_out = [xmlOutFolder,'\',thisUnqId,'.xml'];
        fprintf('XML document formatted for Tethys saving at: %s\n',xml_out)
        m.marshal(l, xml_out) % save the xml file in your path from above

    end

end

fprintf('XML file saved. Now launching submission interface. Please upload the XML file you just generated. \n')

dbSubmit(q) % launch the submission interface

