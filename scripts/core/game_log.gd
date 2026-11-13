class_name GameLog
extends RefCounted
## Passo 93: o diário de jogo ([World]/[Gameplay]/[Core]) só sai com a variável de ambiente TERRAFORGE_LOG definida.
## MEDIDO: print() custa 10–30 ms por linha no console do Windows; havia uma linha por conquista, evento e bônus, no meio da corrida.
## O servidor dedicado e o NetLog (auditoria, DD-050) continuam com print() próprio.

static var enabled := OS.get_environment("TERRAFORGE_LOG") != ""


static func say(text: String) -> void:
	if enabled:
		print(text)
