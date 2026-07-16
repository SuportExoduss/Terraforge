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

            // DD-116: Kit de Terreno de cada civilização (índice = id - 1).
            // O shader COMPÕE o solo com estas cores + ruído; nada é pintado
            // à mão e nenhuma textura planetária pronta é usada.
            float4 _ThemeSoilSecondary[16];
            float4 _ThemeDetail[16];
            float4 _ThemeVegetation[16];
            float4 _ThemeDna[16];   // x=vegetação y=rocha z=poeira w=contraste
            float _TerraSeed;       // muda a cada partida: planeta sempre novo

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

            Varyings Vertex(Attributes input)
            {
                Varyings output;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionHCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
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

                // Amostragem em cruz + curva suave: a fronteira da dominação
                // fica ARREDONDADA e orgânica, sem escadinha de pixels.
                // Leitura FINA (máscara): decide preenchimento e traço.
                float2 maskTexel = _TerritoryMapTexel.xy * 2.5;
                half4 mask =
                    SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap, territoryUV, 0) * 2.0;
                mask += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV + float2(maskTexel.x, 0), 0);
                mask += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV - float2(maskTexel.x, 0), 0);
                mask += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV + float2(0, maskTexel.y), 0);
                mask += SAMPLE_TEXTURE2D_LOD(_TerritoryMap, sampler_TerritoryMap,
                    territoryUV - float2(0, maskTexel.y), 0);
                mask /= 6.0;

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

                // Preenchimento tolerante a frestas (impérios encostados se
                // emendam pela fusão, sem traço entre eles) e BORDA CARTOON
                // preta-tinta apenas na fronteira com terra neutra.
                half fill = smoothstep(0.35, 0.6, mask.a);
                half outline = smoothstep(0.10, 0.30, mask.a) * (1.0 - fill);
                const half3 outlineColor = half3(0.015, 0.015, 0.025);

                // DD-116: o solo do bioma é COMPOSTO aqui, em tempo real.
                // O Kit da civilização dona (lido pelo id, sem interpolação)
                // é misturado por camadas de ruído: manchas de solo
                // secundário, rachaduras/pedrinhas e vegetação rasteira.
                // A cor base vem do mapa borrado, o que preserva a fusão
                // entre impérios vizinhos.
                half3 soil = territoryTint;
                int themeIndex = (int)round(
                    SAMPLE_TEXTURE2D_LOD(_TerritoryIdMap, sampler_TerritoryIdMap,
                        territoryUV, 0).r * 255.0) - 1;

                if (themeIndex >= 0 && themeIndex < 16)
                {
                    float4 dna = _ThemeDna[themeIndex];
                    float3 p = direction * 90.0;

                    // Manchas largas de solo secundário.
                    float patches = TerraNoise(p * 0.6);
                    soil = lerp(soil, _ThemeSoilSecondary[themeIndex].rgb,
                                smoothstep(0.55, 0.85, patches) * 0.6);

                    // Detalhe fino: rachaduras e pedrinhas (densidade = DNA rocha).
                    float grain = TerraNoise(p * 4.0);
                    soil = lerp(soil, _ThemeDetail[themeIndex].rgb,
                                smoothstep(0.72, 0.95, grain) * dna.y * 0.7);

                    // Vegetação rasteira (densidade = DNA vegetação).
                    float flora = TerraNoise(p * 2.2 + 31.7);
                    soil = lerp(soil, _ThemeVegetation[themeIndex].rgb,
                                smoothstep(0.75, 0.95, flora) * dna.x);

                    // Poeira do bioma lava levemente o conjunto (DD-118).
                    soil = lerp(soil, soil * 1.12 + 0.04, dna.z * 0.35);
                }

                // O pixel dominado troca de cor na própria pele do planeta.
                half3 albedo = lerp(baseColor.rgb, soil, fill);
                albedo = lerp(albedo, outlineColor, outline);

                // Iluminação simples e macia (meia-lambert), estilo cartoon.
                Light mainLight = GetMainLight();
                half lighting =
                    saturate(dot(normalize(input.normalWS), mainLight.direction)) * 0.7 + 0.3;

                return half4(albedo * mainLight.color.rgb * lighting, 1.0);
            }
            ENDHLSL
        }
    }
}
