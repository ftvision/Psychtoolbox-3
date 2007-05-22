function ImagingVideoCaptureDemo(filtertype, kwidth)

AssertOpenGL;
screen=max(Screen('Screens'));

if nargin < 1
    filtertype = 1;
end

if nargin < 2
    kwidth=11;
end;

try
    %InitializeMatlabOpenGL;
%    Screen('Preference', 'Verbosity', 6);
    [win winRect]=Screen('OpenWindow', screen, 0, [], [], [], [], [], mor(kPsychNeedFastBackingStore, kPsychNeedImageProcessing));

    Screen('HookFunction', win, 'AppendBuiltin', 'StereoLeftCompositingBlit', 'Builtin:IdentityBlit', 'Offset:1680:0:Scaling:-1.0:1.0');
    Screen('HookFunction', win, 'Enable', 'StereoLeftCompositingBlit');

    % Initial flip to a blank screen:
    Screen('Flip',win);

    % Set text size for info text. 24 pixels is also good for Linux.
    Screen('TextSize', win, 24);
        

    blurshader = LoadGLSLProgramFromFiles('ParametricBoxBlurShader', 1);
    glUseProgram(blurshader);
    glUniform1i(glGetUniformLocation(blurshader, 'Image'), 0);
    glUniform1i(glGetUniformLocation(blurshader, 'FilterMap'), 1);
    glUseProgram(0);
    bluroperator = CreateGLProcessingOperatorFromShader(win, blurshader, 'Parametric box blur operator.');
    
    
    grabber = Screen('OpenVideoCapture', win, 0, [0 0 640 480]);

    blurmaptex = Screen('OpenOffscreenWindow', win, 0, [0 0 640 480]);
    cr = CenterRect([0 0 640 480], winRect);
    xr = cr(RectRight);
    yt = cr(RectTop);
    
    Screen('StartVideoCapture', grabber, 30, 1);

    oldpts = 0;
    count = 0;
    ftex = 0;
    t=GetSecs;
    while ~KbCheck        
        [tex pts nrdropped]=Screen('GetCapturedImage', win, grabber, 1);
        % fprintf('tex = %i  pts = %f nrdropped = %i\n', tex, pts, nrdropped);
        
        if (tex>0)
            ftex = Screen('TransformTexture', tex, bluroperator, blurmaptex, ftex);
            % Draw new texture from framegrabber.
            Screen('DrawTexture', win, ftex); %Screen('Rect', win));
            
            % Show it.
            Screen('Flip', win);
            Screen('Close', tex);
%            Screen('Close', ftex);
            tex=0;
        end;        
        
        count = count + 1;
        [x y buttons] = GetMouse(win);
        if any(buttons)
            x = xr - x;
            y = y - yt;
            if buttons(1)
                blurlevel = 5;
            else
                blurlevel = 0;
            end
            Screen('FillRect', blurmaptex, blurlevel, CenterRectOnPoint([0 0 30 30], x, y));
        end
    end
    telapsed = GetSecs - t
    Screen('StopVideoCapture', grabber);
    Screen('CloseVideoCapture', grabber);
    Screen('CloseAll');
    avgfps = count / telapsed
catch
   Screen('CloseAll');
end;