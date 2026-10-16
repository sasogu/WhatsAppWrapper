# WhatsAppWrapper

Contenedor iOS/iPadOS para una segunda cuenta de WhatsApp via WhatsApp Web.

Carga `https://web.whatsapp.com` en un WKWebView con User-Agent de Safari de escritorio macOS, permitiendo mantener una sesion de WhatsApp independiente de la app oficial.

## Caracteristicas

- Sesion persistente entre cierres
- User-Agent de escritorio para evitar el aviso de navegador no soportado
- Enlaces externos abiertos en Safari
- Gestos de navegacion atras/adelante
- Barra de progreso de carga
- Manejo de errores de conexion
- Compatible con iPadOS 17+ y iOS 17+
- Sin dependencias externas

## Requisitos

- Xcode 26+
- iPadOS 17.0+ / iOS 17.0+
- Apple ID para firma (gratuita)

## Pestañas

La app muestra una pestaña por servicio web. WhatsApp viene incluida; las demás se definen en `WhatsAppWrapper/Services.local.swift`, que no se sube a git. Antes de compilar por primera vez:

```sh
cp WhatsAppWrapper/Services.local.example.swift WhatsAppWrapper/Services.local.swift
```

Cada pestaña indica nombre, icono SF Symbol, URL inicial y dominios que se abren dentro de la app (el resto va a Safari).

## Compilar

Abrir `WhatsAppWrapper.xcodeproj` en Xcode, seleccionar el dispositivo en el menu y pulsar Run (Cmd+R).

## Licencia

MIT
