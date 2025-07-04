% Tecnologico de Monterrey, Campus Ciudad de México
% Presenta: J.M.V.L.
% Matricula: ---------
% ANALISIS DE SISTEMAS DE IMAGENOLOGIA

clc; clear; close all; %Limpieza

%% 1. Carga de la imagen médica
try
    infoDICOM = dicominfo('image-000011.dcm');
    imgOriginal = dicomread(infoDICOM);
    Original = dicomread(infoDICOM);

% La imagen DICOM la saque de https://www.dicomlibrary.com?study=1.2.826.0.1.3680043.8.1055.1.20111103111148288.98361414.79379639
% que es un "repositorio" donde existen archivos DICOM anonimos, que
% elimina la información del paciente que permite identificar al paciente
% por el archivo DICOM, entonces se supone es un espacio 100% seguro,
% además tiene un visor gratuito de archivos DICOM. Mi archivo que escogí
% es un estudio modalidar MR (resonancia magnetica) de la rodilla

catch
    error('Error: No se encontró el archivo DICOM.');
end

% Configurar el tamaño de la ventana del menú
figPrincipal = figure('Name', 'Procesamiento de Imagen Médica', 'NumberTitle', 'off', 'Position', [100 100 1400 800]);

%% 2. Mostrar imágenes iniciales
% Imagen original 
subplot(2,4,1);
imshow(imgOriginal, []);
title('Imagen Original');
colorbar;

% Imagen normalizada
imgOriginal = mat2gray(imgOriginal); %Normalizar [0,1]
subplot(2,4,2);
imshow(imgOriginal, []);
title('Imagen Normalizada');
colorbar;

%% 3. Transformada de Fourier
% Calcular FFT
transformada = fft2(double(imgOriginal));
transformadaCentrada = fftshift(transformada);
espectro = log(1 + abs(transformadaCentrada)); %transformación logaritmica para percibir mejor las diferencias en la imagen

% Mostrar espectro de Fourier
subplot(2,4,3);
imshow(espectro, []);
title('Espectro de Fourier (log)');
colorbar;

%% 4. Mapa de distancia frecuencial
[filas, cols] = size(imgOriginal);
centroX = floor(cols/2) + 1;
centroY = floor(filas/2) + 1;

% Crear matriz de distancias
[X, Y] = meshgrid(1:cols, 1:filas);
distancias = sqrt((X-centroX).^2 + (Y-centroY).^2);

% Mostrar mapa de distancias
subplot(2,4,4);
imshow(distancias, []);
title('Mapa de Distancia Frecuencial');
colorbar;

%% 5. Configuración inicial de filtros
% Valores por defecto (se cambian en el otro menú al seleccionar el tipo de filtro)
radioBajas = min(filas,cols)/8;
radioAltas = min(filas,cols)/16;
radioIntBanda = min(filas,cols)/32;
radioExtBanda = min(filas,cols)/8;

%% 6. Interfaz de usuario
tipoFiltro = menu('Seleccione filtro:', ...
                  'Pasa Bajas', 'Pasa Altas', 'Pasa Banda', 'Rechaza Banda', 'Salir');

while tipoFiltro ~= 5
    % Configurar parámetros según filtro seleccionado
    switch tipoFiltro
        case 1 % Pasa Bajas
            param = inputdlg('Radio para filtro pasa bajas:', 'Parámetros', 1, {num2str(radioBajas)});
            if isempty(param), continue; end
            radioBajas = str2double(param{1});
            mascara = crearMascaraBajas(filas, cols, centroX, centroY, radioBajas);
            nombreFiltro = 'Pasa Bajas';
            
        case 2 % Pasa Altas
            param = inputdlg('Radio para filtro pasa altas:', 'Parámetros', 1, {num2str(radioAltas)});
            if isempty(param), continue; end
            radioAltas = str2double(param{1});
            mascara = crearMascaraAltas(filas, cols, centroX, centroY, radioAltas);
            nombreFiltro = 'Pasa Altas';
            
        case 3 % Pasa Banda
            param = inputdlg({'Radio interno:','Radio externo:'}, 'Parámetros Pasa Banda', 2, ...
                           {num2str(radioIntBanda), num2str(radioExtBanda)});
            if isempty(param), continue; end
            radioIntBanda = str2double(param{1});
            radioExtBanda = str2double(param{2});
            mascara = crearMascaraBanda(filas, cols, centroX, centroY, radioIntBanda, radioExtBanda);
            nombreFiltro = 'Pasa Banda';
            
        case 4 % Rechaza Banda
            param = inputdlg({'Radio interno:','Radio externo:'}, 'Parámetros Rechaza Banda', 2, ...
                           {num2str(radioIntBanda), num2str(radioExtBanda)});
            if isempty(param), continue; end
            radioIntBanda = str2double(param{1});
            radioExtBanda = str2double(param{2});
            mascara = crearMascaraRechazaBanda(filas, cols, centroX, centroY, radioIntBanda, radioExtBanda);
            nombreFiltro = 'Rechaza Banda';
    end
    
    %% 7. Aplicar el filtro seleccionado
    % Mostrar máscara del filtro
    subplot(2,4,5);
    imshow(mascara, []);
    title(['Máscara: ' nombreFiltro]);
    
    % Filtro en dominio de frecuencia
    espectroFiltrado = transformadaCentrada .* mascara;
    
    % Mostrar espectro filtrado
    subplot(2,4,6);
    imshow(log(1 + abs(espectroFiltrado)), []);
    title(['Espectro Filtrado (' nombreFiltro ')']);
    
    % Transformada inversa
    imgFiltrada = abs(ifft2(ifftshift(espectroFiltrado)));
    imgFiltrada = mat2gray(imgFiltrada);
    
    % Imagen filtrada
    subplot(2,4,7);
    imshow(imgFiltrada, []);
    title(['Imagen Filtrada (' nombreFiltro ')']);
    
    % Segmentación con Thresholding
    umbral = mean(imgFiltrada(:)); % Calcula la intensidad media
    imgSegmentada = imgFiltrada > umbral;
    
    % Imagen segmentada
    subplot(2,4,8);
    imshow(imgSegmentada, []);
    title(['Segmentación (' nombreFiltro ') - Umbral: ' num2str(umbral)]);
    
    % Actualizar menú
    tipoFiltro = menu('Seleccione filtro:', ...
                     'Pasa Bajas', 'Pasa Altas', 'Pasa Banda', 'Rechaza Banda', 'Salir');
end

%% Funciones para las mascaras
% Crea máscara pasa bajas
function mascara = crearMascaraBajas(filas, cols, cx, cy, radio)
    [X, Y] = meshgrid(1:cols, 1:filas);
    dist = sqrt((X-cx).^2 + (Y-cy).^2);
    mascara = double(dist <= radio);
end

% Crea máscara pasa altas
function mascara = crearMascaraAltas(filas, cols, cx, cy, radio)
    [X, Y] = meshgrid(1:cols, 1:filas);
    dist = sqrt((X-cx).^2 + (Y-cy).^2);
    mascara = double(dist > radio);
end

% Crea máscara pasa banda
function mascara = crearMascaraBanda(filas, cols, cx, cy, ri, re)
    [X, Y] = meshgrid(1:cols, 1:filas);
    dist = sqrt((X-cx).^2 + (Y-cy).^2);
    mascara = double(dist >= ri & dist <= re);
end

% Crea máscara rechaza banda
function mascara = crearMascaraRechazaBanda(filas, cols, cx, cy, ri, re)
    [X, Y] = meshgrid(1:cols, 1:filas);
    dist = sqrt((X-cx).^2 + (Y-cy).^2);
    mascara = double(~(dist >= ri & dist <= re));
end

%% En caso de que el profe quiera ver alguna imagen en grande

% figure;
% imshow(imagenX, []);
% title('Imagen x en Grande');
