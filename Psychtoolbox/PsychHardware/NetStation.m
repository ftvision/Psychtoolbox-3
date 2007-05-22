function [status error] = NetStation(varargin)
%
% NetStation - Basic control of the EGI/Netstation EEG recording system via
% TCP/IP network connection.
%
% This function was developed and contributed to Psychtoolbox by Gergely Csibra, 2006-2007
% based on Rick Gilmore's routines, 2005. Thanks!
%
%
% General syntax
%
% 	[status, error] = NetStation('command', ...)
%
% 	if status == 0, the command has been succesfully executed
% 	otherwise see string "error" for error message
%
% Commands
%
% 	NetStation('Connect', host [, port])
%
%           Establishes TCP/IP connection to the NetStation host computer.
%           "host" is the hostname as a string (e.g., 'anything.com' or '187.14.176.12')
%           "port" is the ethernet port to be used. Default is 55513.
%
% 	NetStation('Disconnect')
%
%           Disconnects fron NetStation host.
%
% 	NetStation('Synchronize' [, SynchLimit])
%
%           Synchronize to the connected host. "SynchLimit" could specify the maximum allowed difference
%           IN MILLISECONDS. Default is 2.5 ms.
%
% 	NetStation('StartRecording')
%
%           Instructs NetStation to start recording.
%
% 	NetStation('StopRecording')
%
%           Instructs NetStation to stop recording.
%
% 	NetStation('Event' [,code] [,starttime] [,duration] [,keycode1] [,keyvalue1] [...])
%
%           Send an event to the NetStation host.
% 			"code"		The 4-char event code (e.g., 'STIM')
% 						Default: 'EVEN'
% 			"starttime"	The time IN SECONDS when the event started. The VBL time
% 						returned by Screen('Flip') can be passed here as a parameter.
% 						Default: current time.
% 			"duration"	The duration of the event IN SECONDS.
% 						Default: 0.001.
% 			"keycode"	The 4-char code of a key (e.g., 'tria').
% 			"keyvalue"	The integer value of the key (>=-32767 <=32767)
% 			The keycode-keyvalue pairs can be repeated arbitrary times.
%
%   Uses TCP/UDP/IP Toolbox 2.0.5, a third party GPL'ed
%   open source toolbox, which is included in Psychtoolbox,
%   but also available from the Mathworks website:
%   http://www.mathworks.com/matlabcentral/fileexchange/loadFile.do?objectId=345
%
%   Created by Gergely Csibra, 2006-2007
%   based on Rick Gilmore's routines, 2005
%


persistent NSIDENTIFIER;
persistent NSSTATUS;
persistent NSRECORDING;

DefaultSynchLimit=2.5;		% The accuracy of synchronization in milliseconds

if nargin < 1
    if(isempty(NSSTATUS))
        status = -1;
    else
        status = NSSTATUS;
    end
else
    switch lower(varargin{1})
        case 'connect'
            if(nargin<2)
                status = 2;
            else
                netStationHostName = varargin{2};
                if (~isempty(NSIDENTIFIER)) && (NSIDENTIFIER > 0)
                    send(NSIDENTIFIER,'X');
                    rep=receive(NSIDENTIFIER,1);
                    pnet( NSIDENTIFIER, 'close' );
                    NSIDENTIFIER = 0;
                end
                port=55513;
                if nargin > 2
                    port =  = varargin{3};
                end
                c = pnet( 'tcpconnect', netStationHostName, port );
                if(c < 0)
                    status = 3;
                else
                    NSIDENTIFIER = c;
                    NSRECORDING=0;
                    send(NSIDENTIFIER,'QMAC-');
                    rep=receive(NSIDENTIFIER,1);
                    switch char(rep)
                        case 'F'
                            status=4;
                        case 'I'
                            vers=receive(NSIDENTIFIER,1);
                            if(int8(vers) ~= 1)
                                status = 5;
                            else
                                status = 0;
                            end
                    end
                    if status ~= 0
                        pnet( NSIDENTIFIER, 'close' );
                        NSIDENTIFIER = 0;
                    end
                end
            end
        case 'disconnect'
            if isempty(NSIDENTIFIER) || (NSIDENTIFIER < 0)
                status = 1;
            else
                if NSRECORDING
                    WaitSecs(.5);
                    send(NSIDENTIFIER,'E');
                    rep=receive(NSIDENTIFIER,1);
                    NSRECORDING=0;
                end
                WaitSecs(1.);
                send( NSIDENTIFIER,'X');
                rep=receive(NSIDENTIFIER,1);
                WaitSecs(.5);
                pnet( NSIDENTIFIER, 'close' );
                NSIDENTIFIER = -1;
                status = 0;
            end
        case 'synchronize'
            if isempty(NSIDENTIFIER) || (NSIDENTIFIER < 0)
                status = 1;
            else
                NSSynchLimit = DefaultSynchLimit;
                if nargin > 1
                    NSSynchLimit = varargin{2};
                end
                if NSSynchLimit < .5 || NSSynchLimit > 50,
                    NSSynchLimit = DefaultSynchLimit;
                end
                df=10000;
                n=1;
                while df > NSSynchLimit && n < 100
                    send(NSIDENTIFIER,'A');
                    receive(NSIDENTIFIER,1);
                    now=GetSecs();
                    send(NSIDENTIFIER,'T',int32(now*1000));
                    receive(NSIDENTIFIER,1);
                    ack=GetSecs();
                    df=1000*(ack-now);
                    status=0;
                    n=n+1;
                end
                if n>=100 warning('\nNetstation synchronization did not succeed within %.1f ms\nSynchronizatoin accuracy is %.1f ms\n',NSSynchLimit,df); end
                %fprintf('synch: %.1f ms at the %ith attempt\n',df,n-1);
            end
        case 'startrecording'
            if isempty(NSIDENTIFIER) || (NSIDENTIFIER < 0)
                status = 1;
            else
                if ~NSRECORDING
                    send(NSIDENTIFIER,'B');
                    rep=receive(NSIDENTIFIER,1);
                    NSRECORDING=1;
                end
                status=0;
            end
        case 'stoprecording'
            if isempty(NSIDENTIFIER) || (NSIDENTIFIER < 0)
                status = 1;
            else
                if NSRECORDING
                    WaitSecs(.5);
                    send(NSIDENTIFIER,'E');
                    rep=receive(NSIDENTIFIER,1);
                    NSRECORDING=0;
                end
                status=0;
            end
        case 'event'
            if isempty(NSIDENTIFIER) || (NSIDENTIFIER < 0)
                fprintf('%e',NSIDENTIFIER);
                status = 1;
            else
                if nargin < 2
                    event='EVEN';
                else
                    event=[char(varargin{2}) '    '];
                end
                if nargin < 3
                    start=GetSecs();
                else
                    start=varargin{3};
                end
                if nargin < 4
                    duration=.001;
                else
                    duration=varargin{4};
                end
                if isnumeric(duration)
                    if duration > 120
                        duration=.001;
                    else
                        duration= duration;
                    end
                end

                karg=nargin-4;
                keyn=floor(karg/2);
                send(NSIDENTIFIER,'D',uint16(15+keyn*12),int32(start*1000),uint32(duration*1000),event(1:4),int16(0),uint8(keyn));
                for k=1:keyn
                    id=[char(varargin{(k-1)*2+5}) '    '];
                    val=int16(varargin{k*2+4});
                    send(NSIDENTIFIER,id(1:4),'shor',uint16(2),val(1));
                end

                rep=receive(NSIDENTIFIER,1);
                status=0;
            end
        otherwise
            status=7;
    end
end

error=nserr(status);

return


function send(con,varargin)
i=1;
while i <= nargin-1
    pnet(con,'write',varargin{i});
    i = i+1;
end
return



function rep=receive(con,len)

rep=pnet(con,'read',len,'char');

return



function errstr=nserr(status)

switch status
    case -1
        errstr='NetStation has not been initialized';
    case 0
        errstr='No error';
    case 1
        errstr='NetStation host not connected';
    case 2
        errstr='NS connect: NetStation host name must be specified';
    case 3
        errstr='NS connect: Unable to connect to host';
    case 4
        errstr='NS connect: ECI error';
    case 5
        errstr='NS connect: Unknown ECI version';
    case 6
        errstr='NS event: Unsuccesful';
    case 7
        errstr='Unknown NetStation command'
    otherwise
        errstr='NS unknown error';
end

return