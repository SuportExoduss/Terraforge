// Terraforge/PlanetSurface — a pele do planeta.
// Mistura a cor original do modelo com o MAPA DE POSSE territorial
// (textura global _TerritoryMap): onde uma civilização domina, o pixel
// da própria superfície muda de cor — sem camadas por cima (DD-110).
Shader "Terraforge/PlanetSurface"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            // Globais definidos pelo TerritoryPainter (iguais para todos os
            // materiais do planeta).
            TEXTURE2D(_TerritoryMap);
            SAMPLER(sampler_TerritoryMap);
            TEXTURE2D(_TerritoryIdMap);
            SAMPLER(sampler_TerritoryIdMap);
            float4 _PlanetCenter;
            float4 _TerritoryMapTexel; // xy = 1/tamanho (para suavizar bordas)

            // DD-116/DD-120: Kit de Terreno de cada civilização (índice =
            // id - 1). O piso é a TEXTURA E00 do theme (atlas abaixo); as
            // cores compõem variação procedural por cima — nada é pintado
            // à mão e nenhuma textura planetária pronta é usada.
            float4 _ThemeSoilSecondary[16];
            float4 _ThemeDetail[16];
            float4 _ThemeVegetation[16];
            float4 _ThemeDna[16];    // x=vegetação y=rocha z=poeira w=contraste
            float4 _ThemeGroundParams[16]; // x=tiling, y=tem textura?
            float _TerraSeed;        // muda a cada partida: planeta sempre novo
            float _ThemeGroundCount; // fatias no atlas de pisos

            // Atlas dos pisos (E00): fatia N = chão da civilização N+1.
            TEXTURE2D_ARRAY(_ThemeGroundArray);
            SAMPLER(sampler_ThemeGroundArray);

            // Atlas dos relevos (E00): o mapa normal do chão de cada
            // civilização — o terreno ganha ondulações iluminadas.
            TEXTURE2D_ARRAY(_ThemeGroundNormalArray);
            SAMPLER(sampler_ThemeGroundNormalArray);

            // Projeção triplanar: a textura é aplicada pelos 3 eixos do
            // mundo e misturada pela normal — cobre a esfera inteira sem
            // esticar nos polos (uma projeção única sempre estica).
            half3 SampleGroundTriplanar(int slice, float3 positionWS, float3 normalWS, float tiling)
            {
                float3 weights = abs(normalWS);
                weights /= max(weights.x + weights.y + weights.z, 0.001);
                float3 uvw = (positionWS - _PlanetCenter.xyz) * (tiling * 0.01);

                half3 x = SAMPLE_TEXTURE2D_ARRAY(_ThemeGroundArray,
                    sampler_ThemeGroundArray, uvw.zy, slice).rgb;
                half3 y = SAMPLE_TEXTURE2D_ARRAY(_ThemeGroundArray,
                    sampler_ThemeGroundArray, uvw.xz, slice).rgb;
                half3 z = SAMPLE_TEXTURE2D_ARRAY(_ThemeGroundArray,
                    sampler_ThemeGroundArray, uvw.xy, slice).rgb;

                return x * weights.x + y * weights.y + z * weights.z;
            }

            // Relevo triplanar (mistura UDN): perturba a normal do planeta
            // com o mapa normal do piso — as ondulações da areia reagem à
            // luz de verdade, pelos 3 eixos, sem esticar nos polos.
            half3 GroundReliefNormal(int slice, float3 positionWS, float3 normalWS,
                                     float tiling, half strength)
            {
                float3 weights = abs(normalWS);
                weights /= max(weights.x + weights.y + weights.z, 0.001);
                float3 uvw = (positionWS - _PlanetCenter.xyz) * (tiling * 0.01);

                half3 nx = SAMPLE_TEXTURE2D_ARRAY(_ThemeGroundNormalArray,
                    sampler_ThemeGroundNormalArray, uvw.zy, slice).rgb * 2.0 - 1.0;
                half3 ny = SAMPLE_TEXTURE2D_ARRAY(_ThemeGroundNormalArray,
                    sampler_ThemeGroundNormalArray, uvw.xz, slice).rgb * 2.0 - 1.0;
                half3 nz = SAMPLE_TEXTURE2D_ARRAY(_ThemeGroundNormalArray,
                    sampler_ThemeGroundNormalArray, uvw.xy, slice).rgb * 2.0 - 1.0;

                half3 bump =
                    half3(0.0, nx.y, nx.x) * weights.x +
                    half3(ny.x, 0.0, ny.y) * weights.y +
                    half3(nz.x, nz.y, 0.0) * weights.z;

                return normalize(normalWS + bump * strength);
            }

            // Ruído de valor barato (hash + interpolação suave), suficiente
            // para manchas orgânicas de solo em estilo cartoon.
            float TerraHash(float3 p)
            {
                p = frac(p * 0.3183099 + _TerraSeed);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float TerraNoise(float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                return lerp(
                    lerp(lerp(TerraHash(i + float3(0, 0, 0)), TerraHash(i + float3(1, 0, 0)), f.x),
                         lerp(TerraHash(i + float3(0, 1, 0)), TerraHash(i + float3(1, 1, 0)), f.x), f.y),
                    lerp(lerp(TerraHash(i + float3(0, 0, 1)), TerraHash(i + float3(1, 0, 1)), f.x),
                         lerp(TerraHash(i + float3(0, 1, 1)), TerraHash(i + float3(1, 1, 1)), f.x), f.y),
                    f.z);
            }

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            // Altura da camada de bioma num ponto do mapa (DD-121): posse
            // esfumada × altura do theme dono da vizinhança. A camada SOBE
            // no miolo do domínio e AFINA até acabar na borda.
            float LayerHeight(float2 territoryUV)
            {
                float2 t = _TerritoryMapTexel.xy * 5.0;
                half fillA =
                    SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap, territoryUV, 0).a * 2.0;
                fillA += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV + float2(t.x, 0), 0).a;
                fillA += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV - float2(t.x, 0), 0).a;
                fillA += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV + float2(0, t.y), 0).a;
                fillA += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV - float2(0, t.y), 0).a;
                fillA /= 6.0;

                // Altura do dono: o maior theme presente na vizinhança
                // (a rampa continua até o fim do esfumado).
                float height = 0.0;
                [unroll]
                for (int k = 0; k < 5; k++)
                {
                    float2 offsets[5] = {
                        float2(0, 0), float2(t.x, 0), float2(-t.x, 0),
                        float2(0, t.y), float2(0, -t.y)
                    };
                    int id = (int)round(SAMPLE_TEXTURE2D_LOD(_TerritoryIdMap,
                        sampler_TerritoryIdMap, territoryUV + offsets[k], 0).r * 255.0);
                    if (id >= 1 && id <= 16)
                    {
                        height = max(height, _ThemeGroundParams[id - 1].w);
                    }
                }

                return smoothstep(0.06, 0.9, fillA) * height;
            }

            Varyings Vertex(Attributes input)
            {
                Varyings output;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                // DD-121: a camada do bioma LEVANTA a pele do planeta.
                // Deslocamento radial no vértice — a malha e as colisões
                // nunca mudam (DD-114); o chão físico acompanha via
                // TerritoryPainter.GetElevationAt (mesma conta, na CPU).
                float3 dir = normalize(output.positionWS - _PlanetCenter.xyz);
                float2 territoryUV = float2(
                    atan2(dir.z, dir.x) / (2.0 * PI) + 0.5,
                    asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5);
                output.positionWS += dir * LayerHeight(territoryUV);

                output.positionHCS = TransformWorldToHClip(output.positionWS);
                return output;
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                // Cor original do planeta neste ponto.
                half4 baseColor =
                    SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;

                // Direção do centro ao pixel → coordenada no mapa de posse
                // (projeção equiretangular: longitude/latitude).
                float3 direction = normalize(input.positionWS - _PlanetCenter.xyz);
                float2 territoryUV = float2(
                    atan2(direction.z, direction.x) / (2.0 * PI) + 0.5,
                    asin(clamp(direction.y, -1.0, 1.0)) / PI + 0.5);

                // Leitura LARGA (fusão): mistura as cores dos vizinhos numa
                // faixa de transição — impérios encostados se fundem
                // (o "ambiente de transição" dos futuros biomas).
                float2 blendTexel = _TerritoryMapTexel.xy * 5.0;
                half4 blend =
                    SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap, territoryUV, 0) * 2.0;
                blend += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV + float2(blendTexel.x, 0), 0);
                blend += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV - float2(blendTexel.x, 0), 0);
                blend += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV + float2(0, blendTexel.y), 0);
                blend += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV - float2(0, blendTexel.y), 0);
                blend /= 6.0;

                half3 territoryTint = blend.rgb / max(blend.a, 0.001);

                // A fronteira do domínio é o MATERIAL ACABANDO: um esfumado
                // largo em que a areia (ou grama, neve...) vai rareando até
                // sumir na terra neutra — e, entre dois impérios colados,
                // os dois materiais se mesclam na faixa (pedido do Diretor;
                // a borda preta cartoon foi removida por enquanto).
                half fill = smoothstep(0.06, 0.9, blend.a);

                // DD-116: o solo do bioma é COMPOSTO aqui, em tempo real.
                // O Kit da civilização dona (lido pelo id, sem interpolação)
                // é misturado por camadas de ruído: manchas de solo
                // secundário, rachaduras/pedrinhas e vegetação rasteira.
                // A cor base vem do mapa borrado, o que preserva a fusão
                // entre impérios vizinhos.
                half3 soil = territoryTint;
                float3 planetNormal = normalize(input.normalWS);
                half3 shadingNormal = planetNormal;
                int themeIndex = (int)round(
                    SAMPLE_TEXTURE2D_LOD(_TerritoryIdMap, sampler_TerritoryIdMap,
                        territoryUV, 0).r * 255.0) - 1;

                if (themeIndex >= 0 && themeIndex < 16)
                {
                    float4 dna = _ThemeDna[themeIndex];
                    float3 p = direction * 90.0;

                    // E00 (DD-120): o PISO do bioma é o material real da
                    // civilização — cor (com AO assado) tingida pela cor do
                    // território (preserva a fusão) + RELEVO iluminado.
                    float4 groundParams = _ThemeGroundParams[themeIndex];
                    if (groundParams.y > 0.5 && themeIndex < (int)_ThemeGroundCount)
                    {
                        half3 groundTex = SampleGroundTriplanar(
                            themeIndex, input.positionWS, planetNormal, groundParams.x);
                        half3 tinted = groundTex * territoryTint * 2.0;
                        soil = lerp(soil, tinted, 0.85);

                        // O relevo acompanha o esfumado: forte no meio do
                        // domínio, sumindo junto com o material na borda.
                        if (groundParams.z > 0.01)
                        {
                            half3 relief = GroundReliefNormal(
                                themeIndex, input.positionWS, planetNormal,
                                groundParams.x, groundParams.z);
                            shadingNormal = normalize(
                                lerp(planetNormal, relief, fill));
                        }
                    }

                    // Com textura real, o ruído vira TEMPERO (variação sutil
                    // por seed); sem textura, ele é o próprio solo.
                    half spice = groundParams.y > 0.5 ? 0.35 : 1.0;

                    // Manchas largas de solo secundário.
                    float patches = TerraNoise(p * 0.6);
                    soil = lerp(soil, _ThemeSoilSecondary[themeIndex].rgb,
                                smoothstep(0.55, 0.85, patches) * 0.6 * spice);

                    // Detalhe fino: rachaduras e pedrinhas (densidade = DNA rocha).
                    float grain = TerraNoise(p * 4.0);
                    soil = lerp(soil, _ThemeDetail[themeIndex].rgb,
                                smoothstep(0.72, 0.95, grain) * dna.y * 0.7 * spice);

                    // Vegetação rasteira (densidade = DNA vegetação).
                    float flora = TerraNoise(p * 2.2 + 31.7);
                    soil = lerp(soil, _ThemeVegetation[themeIndex].rgb,
                                smoothstep(0.75, 0.95, flora) * dna.x * spice);

                    // Poeira do bioma lava levemente o conjunto (DD-118).
                    soil = lerp(soil, soil * 1.12 + 0.04, dna.z * 0.35);
                }

                // O pixel dominado troca de material na própria pele do
                // planeta; na borda, o material vai "acabando" (fill).
                half3 albedo = lerp(baseColor.rgb, soil, fill);

                // Iluminação simples e macia (meia-lambert), estilo cartoon
                // — com a normal perturbada pelo relevo do piso.
                Light mainLight = GetMainLight();
                half lighting =
                    saturate(dot(shadingNormal, mainLight.direction)) * 0.7 + 0.3;

                return half4(albedo * mainLight.color.rgb * lighting, 1.0);
            }
            ENDHLSL
        }
    }
}
