clc
clear all
close all

%% Importa��o de dados pr�-tratados         
    display('Importa��o de dados da MTR e MRs');
      
    
    load CERM.mat %%Arquivo externo de temperatura hist�rica ponderados pela vari�vel CERM
  
     
    %% DAdos de demanda s�o carregados
     
    fileToRead='full_Modelo_rotulo.xlsx';      %% Hist�rico de dados de carga por MR
    [Load, string] = xlsread(fileToRead, 'MR1'); %% Escolha Manual: MR1, MR2 (Macro-regi�es)
    Load=Load';
    [tsize,pos1] = size(string);
    [feriado] =  xlsread(fileToRead, 'feriado'); %% Carregar tabela de feriados parao per�odo considerado.
     feriado=feriado';
%%     
%Etapa de rotula��o
  
i=1; 
    
    for j = 1: length(string)
        temp=char(string(j));
        year(j) = str2double(temp(1:4));      
        month(j)= str2double(temp(6:7));
        day(j)  = str2double(temp(9:10));
        hour(j) = i;
        i=i+1;
        if(i>24) 
            i=1; 
        end
    end

    dayOfWeek           = weekday(string)';                 
    
    %%
    %Lag de carga (AFTER FAC STUDIES)
   
    preWeekSameHourLoad = [NaN(1,168), Load(1:end-168)];  
    preDaySameHourLoad  = [NaN(1,24), Load(1:end-24)];    
    prehour = [NaN(1,1), Load(1:end-1)];
    pre2WeekSameHourLoad = [NaN(1,336), Load(1:end-336)];
  
   
    %% Lags de temperatura para treinamento
    %Escolha manual
   
    preDaytemp24 = [NaN(1,1), MR1_cerm1(1:end-1)]; 
    preDaytemp25 = [NaN(1,2), MR1_cerm1(1:end-2)];
    preDaytemp26 = [NaN(1,3), MR1_cerm1(1:end-3)];
    
    
   %% Vari�veis Dummy
    
        for tl=1:1:tsize;
        if dayOfWeek(:,tl) == 6
            daypattern(:,tl) = 1;
        elseif dayOfWeek(:,tl) == 7
              daypattern(:,tl) = 2;
        else
             daypattern(:,tl) = 0;
        end
    end
    
 %%% ANN MLP

%% generate predictors 

in(1,:) = month;
in(2,:) = dayOfWeek;  
in(3,:) = hour; 
in(4,:) = feriado;
in(5,:) = preWeekSameHourLoad;  % FAC studies LOAD
in(6,:) = prehour;   % FAC studies LOAD
in(7,:) = pre2WeekSameHourLoad; % FAC studies LOAD
in(8,:) = MR1_cerm1; %Ajuste manual
in(8,:) = preDaytemp24;
in(9,:) = preDaytemp25;



JA = 504; %Janela de treinamento para Conjunto 1 e Conjunto 2
%Ajuste manual de acordo com os dados e per�odo de testes


%%
% Testes para o Conjunto 2
valind = in(:,1+JA:12528+JA);
ValidLoad = Load(1,1+JA:12528+JA);
testin = in(:,12529+JA:12696+JA);
testLoad = Load(1,12529+JA:12696+JA);

%%
%Testes para o Conjunto 1 (Habilita��o Manual para escolha do Conjunto 1

% valind = in(:,1+JA:9672+JA);
% ValidLoad = Load(1,1+JA:9672+JA);
% %Teste
% testin = in(:,9673+JA:9840+JA);
% testLoad = Load(1,9673+JA:9840+JA);


%% Treinamento da Rede Neural

    min_err     = inf;
    display('Treinamento em Progresso.......');
    display('OBS: CTRL+C para interromper simula��o');
  
    
  for neurons_no = 13:3:48; %Varia��o do n�mero de neur�nios Camada Intermedi�ria (vari�vel)
      neurons_no
         
       for n = 1:1:10; %Itera��es para n neur�nios
                
        net = feedforwardnet(neurons_no);  
        [net,tr] = trainlm(net, valind, ValidLoad);
        NNpredicted(n,:) = sim(net, testin);
        err(n,:)    = testLoad - NNpredicted(n,:);
        epochs(n,:) = tr.num_epochs;
        errpct(n,:) = abs(err(n,:))./testLoad*100;            
        MAPE(n,:)  = mean(errpct(n,:));     
        fprintf('Current MAPE(Mean Absolute Percent Error):  %0.3f%%\n',MAPE(n,:)); 
                      
        end
       
     %Agrega��o de dados para armazenamento do MAPE m�nimo GLOBAL
     t = neurons_no-5;
     [MAPE_min,POS] =  min(MAPE);   %Obter o melhor resultado das n rodadas 
     MAPE_minglobal(t,:) = MAPE_min; 
     Npredicted1(t,:) = NNpredicted(POS,:);
     Errptc1(t,:) = errpct(POS,:);  
     epochs1(t,:) = epochs(POS,:);
     fL = reshape(Npredicted1(t,:), 24, length(Npredicted1(t,:))/24)';
     tY = reshape(testLoad, 24, length(testLoad)/24)';
     peakerrpct(t,:) = abs(max(tY,[],2) - max(fL,[],2))./max(tY,[],2) * 100;
       
  end
  
  
%% Fun��o PLOT b�sica para verifica��o inicial

figure(22673);
t1=[1:length(testLoad)];
plot(t1,Npredicted1);  hold all;
plot(t1,testLoad);             hold off;
legend('forecasted load', 'Actual load');
title('Carga Atual VS Carga Previssta - 24 horas','Fontsize', 12,'color','b');   ylabel('Load');   xlabel('Hour'); 


