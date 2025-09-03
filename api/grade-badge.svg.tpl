{{- $colors := dict 
    "A" "#4c1"
    "B" "#97ca00"
    "C" "#a4a61d"
    "D" "#dfb317"
    "E" "#fe7d37"
    "F" "#e05d44"
    "G" "#007ec6"
-}}
{{- $grade := getenv "GRADE" -}}
{{- $color := index $colors $grade -}}
<svg xmlns="http://www.w3.org/2000/svg" width="17" height="20">
<clipPath id="B">
<rect width="17" height="20" rx="3" fill="#fff"/>
</clipPath>
<g clip-path="url(#B)">
<path fill="{{ $color }}" d="M0 0h17v20H0z"/>
<path fill="url(#A)" d="M0 0h17v20H0z"/>
</g>
<g text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
<text x="85" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="70">{{ $grade }}</text>
<text x="85" y="140" transform="scale(.1)" fill="#fff" textLength="70">{{ $grade }}</text>
</g>
</svg>
