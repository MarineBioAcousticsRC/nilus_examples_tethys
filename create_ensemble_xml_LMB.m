%% create_ensemble_xml_LMB.m

% LMB 10/23/2025; lbaggett@ucsd.edu
% this script will create ensembles for Tethys
% an ensemble groups instrument deployments together
% exactly what we need to do for tracks, since data comes from cross-fixing
% bearing angles to two instruments

xml_out = 'F:\Tracking\tethys_upload\ensembles\SOCAL_W_01_ensemble.xml'; % path to save ensemble xml file

q=dbInit('Server','breach.ucsd.edu','Port',9779);
% dbOpenSchemaDescription(q,'Ensemble'); % open ensemble schema
import nilus.* % import Nilus, this provides Java objects that correspond to XML elements

% create elements
e = Ensemble();
h = Helper();
m = MarshalXML();
h.createRequiredElements(e)

% set ensemble ID
e.setId('SOCAL_W_01_ensemble') % set the ensemble ID name for this deployment

% set units (associate this unit with an actual deployment)
h.createElement(e,'Unit')
un = e.getUnit();
u = UnitGroup();
u.setUnitId(h.toXsInteger(1))
u.setDeploymentId('SOCAL_W_01_WE_C4') % first 4 channel
un.add(u)
u = UnitGroup();
u.setUnitId(h.toXsInteger(2))
u.setDeploymentId('SOCAL_W_01_WS_C4') % second 4 channel
un.add(u)

% set zero position
% load structs where I saved coordinates
load('F:\Tracking\Instrument_Orientation\SOCAL_W_01\SOCAL_W_01_WE\dep\SOCAL_W_01_WE_harp4chPar');
hydLoc{1} = recLoc;
load('F:\Tracking\Instrument_Orientation\SOCAL_W_01\SOCAL_W_01_WS\dep\SOCAL_W_01_WS_harp4chPar');
hydLoc{2} = recLoc;
h0 = mean([hydLoc{1}; hydLoc{2}]);
% add values to ensemble
h.createElement(e,'ZeroPosition');
zero = e.getZeroPosition();
zero.setLatitude(h0(1)) % degrees N
zero.setLongitude(h0(2)+360) % degrees E
zero.setElevationInstrumentM(h.toXsDouble(h0(3))) % m below sea surface (in schema, this is called ElevationInstrument_m)

% m.marshal(e) % if you want to take a look at it before you upload

m.marshal(e, xml_out) % save the xml file in your path from above
dbSubmit('Server','breach.ucsd.edu','Port',9779) % launch the submission interface
