Casos de Uso del Smart Contract P2P con Consentimiento Mutuo
Cualquier Parte Puede Iniciar la Propuesta
El contrato permite que tanto el comprador como el vendedor puedan iniciar una propuesta. La negociación de términos se realiza off-chain, y el contrato maneja el acuerdo final entre ambas partes.

Estados del Contrato


FASE DE PROPUESTA:
- Proposed: Una parte creó propuesta
  * Si vendedor propone: Fondos YA depositados (funded=true)
  * Si comprador propone: Sin fondos aún (funded=false)
- Accepted: Ambas partes acordaron términos
  * Si vendedor inició: Listo para fiat (fondos ya bloqueados)
  * Si comprador inició: Vendedor debe depositar crypto
- Rejected: Propuesta rechazada o cancelada
FASE DE EJECUCIÓN:
- Funded: Crypto bloqueado, esperando transferencia fiat
- ToRefundTimeout: Vendedor pidió reembolso
- Disputed: Disputa levantada
- Completed: Transacción completada
- Cancelled: Escrow cancelado/reembolsado
CASOS DE USO - VENDEDOR INICIA PROPUESTA (CON FUNDING INMEDIATO)
Caso 1: Vendedor Propone + Deposita → Comprador Acepta ✅
Flujo: Vendedor deposita crypto al proponer → Comprador acepta → Ejecución inmediata

Pasos:

Negociación Off-Chain: Chat/Telegram para acordar términos básicos

Vendedor crea propuesta Y deposita crypto simultáneamente:

createProposal(comprador, USDT, 1000, 850, "EUR", 24h) + envía 1000 USDT

Estado: Proposed (funded=true)

1000 USDT YA bloqueados en contrato

Comprador revisa términos y acepta: acceptProposal(escrowId)

Estado: Proposed → Funded (salto directo, sin paso intermedio)

Comprador envía 850 EUR inmediatamente (off-chain)

Vendedor confirma: completeTransaction(escrowId)

Estado: Funded → Completed

Total: Solo 3 transacciones on-chain

Caso 2: Vendedor Deposita → Comprador Rechaza → Reembolso Automático ❌
Flujo: Fondos depositados → Rechazo → Protección del vendedor

Pasos:

Vendedor crea propuesta con términos + deposita 1000 USDT

Estado: Proposed (funded=true)

Fondos bloqueados preventivamente

Comprador ve discrepancias vs negociación previa

Comprador rechaza: rejectProposal(escrowId, "Términos no acordados")

Estado: Proposed → Cancelled

Reembolso automático: 1000 USDT devueltos al vendedor inmediatamente

Sin fees deducidos (propuesta rechazada)

Caso 3: Vendedor Deposita → Vendedor Cancela → Auto-reembolso ❌
Flujo: Vendedor se arrepiente después de depositar → Cancelación segura

Pasos:

Vendedor crea propuesta + deposita fondos

Vendedor recibe mejor oferta de otro comprador

Vendedor auto-cancela: cancelProposal(escrowId, "Mejor oferta recibida")

Estado: Proposed → Cancelled

Reembolso inmediato: Sus 1000 USDT devueltos

Comprador notificado de cancelación

Caso 4: Vendedor Deposita → Propuesta Expira → Reembolso Automático ⏰
Flujo: Fondos depositados → Sin respuesta del comprador → Protección temporal

Pasos:

Vendedor crea propuesta + deposita crypto con deadline de 7 días

Comprador no responde (ocupado, no vio notificación, etc.)

Sistema detecta expiración después de 7 días

isProposalValid() retorna false

Reembolso automático o vendedor puede reclamar fondos

Protección contra fondos bloqueados indefinidamente

CASOS DE USO - COMPRADOR INICIA PROPUESTA (SIN FUNDING INMEDIATO)
Caso 5: Comprador Propone → Vendedor Acepta → Vendedor Deposita ✅
Flujo: Comprador solicita → Vendedor acepta → Vendedor deposita → Ejecución

Pasos:

Negociación Off-Chain: Comprador busca crypto, acuerda términos

Comprador crea propuesta: createProposal(vendedor, USDT, 1000, 850, "EUR", 24h)

Estado: Proposed (funded=false)

Sin fondos depositados aún

Vendedor revisa términos y acepta: acceptProposal(escrowId)

Estado: Proposed → Accepted

Vendedor deposita crypto: fundEscrow(escrowId)

Estado: Accepted → Funded

Ahora 1000 USDT bloqueados

Comprador envía 850 EUR (off-chain)

Vendedor confirma: completeTransaction(escrowId)

Estado: Funded → Completed

Total: 4 transacciones on-chain

Caso 6: Comprador Propone → Vendedor Rechaza ❌
Flujo: Comprador solicita → Vendedor no está de acuerdo → Rechazo

Pasos:

Comprador crea propuesta con precio favorable para él

Estado: Proposed (funded=false)

Sin riesgo para nadie

Vendedor considera el precio muy bajo

Vendedor rechaza: rejectProposal(escrowId, "Precio insuficiente")

Estado: Proposed → Rejected

Sin fondos involucrados en ningún momento

Caso 7: Comprador Propone → Comprador Cancela ❌
Flujo: Comprador solicita → Encuentra mejor deal → Auto-cancelación

Pasos:

Comprador crea propuesta pero encuentra mejor precio en otro lado

Comprador auto-cancela: cancelProposal(escrowId, "Encontré mejor precio")

Estado: Proposed → Rejected

Sin consecuencias financieras

Caso 8: Comprador Propone → Vendedor Acepta + Deposita → Ejecución ✅
Flujo: Comprador solicita → Vendedor acepta y deposita simultáneamente

Pasos:

Comprador crea propuesta: createProposal(vendedor, USDT, 1000, 850, "EUR", 24h)

Estado: Proposed (funded=false)

Vendedor acepta Y deposita simultáneamente: acceptProposal(escrowId) + 1000 USDT

Estado: Proposed → Funded (salto directo)

Fondos bloqueados al aceptar

Comprador envía 850 EUR (off-chain)

Vendedor confirma: completeTransaction(escrowId)

Estado: Funded → Completed

Total: 3 transacciones on-chain (igual eficiencia que vendedor iniciando)

CASOS DE USO - POST-ACEPTACIÓN
Caso 9: Vendedor Depositó → Cancelación Solo Después de Timeout ❌
Flujo: Fondos bloqueados → Solicitud de cancelación → Timeout obligatorio

Pasos:

Estado: Funded (vendedor depositó al proponer o al aceptar)

1000 USDT bloqueados en contrato

Vendedor quiere cancelar: requestRefund(escrowId)

Estado: Funded → ToRefundTimeout

NO hay cancelación inmediata

Inicia período de timeout (ej: 24h)

Durante timeout: Comprador puede disputar si envió fiat

Después del timeout: Si no hay disputa, vendedor puede ejecutar reembolso

executeRefund(escrowId) → Estado: ToRefundTimeout → Cancelled

Caso 10: Comprador Inició + Vendedor Aceptó → Cancelación → Sin Fondos ❌
Flujo: Acuerdo sin fondos → Cancelación limpia → Sin consecuencias

Pasos:

Estado: Accepted (funded=false)

Vendedor aún no depositó crypto

Cambio de situación: Mejor oportunidad, cambio de planes, etc.

Cualquier parte cancela: cancelProposal(escrowId, "Cambio de circunstancias")

Estado: Accepted → Rejected

Sin fondos involucrados, cancelación totalmente limpia

CASOS DE USO - EJECUCIÓN Y PROBLEMAS
Caso 11: Flujo Perfecto desde Vendedor (Optimizado) ✅
Flujo: Vendedor deposita al proponer → Aceptación → Pago fiat inmediato

Pasos:

Vendedor propone + deposita en una transacción

Comprador acepta → Estado: Funded directo

Comprador envía fiat inmediatamente con comprobante

Vendedor confirma rápido → Completed

Solo 3 transacciones on-chain total

Tiempo mínimo de ejecución

Caso 12: Flujo desde Comprador (Optimizado) ✅
Flujo: Comprador propone → Vendedor acepta + deposita → Pago fiat

Pasos:

Comprador propone (sin fondos)

Vendedor acepta + deposita simultáneamente → Estado: Funded directo

Comprador envía fiat → Vendedor confirma → Completed

Solo 3 transacciones on-chain total (mismo que vendedor iniciando)

Ambos flujos igualmente eficientes

Caso 13: Vendedor Depositó → Comprador No Envía Fiat → Reembolso ↩️
Flujo: Fondos ya bloqueados → Sin pago → Protección del vendedor

Pasos:

Estado: Funded (vendedor ya depositó al proponer)

Comprador desaparece o cambia de opinión

Vendedor espera tiempo razonable, solicita: requestRefund(escrowId)

Estado: Funded → ToRefundTimeout

Comprador no disputa ni responde

Vendedor ejecuta: executeRefund(escrowId)

Estado: ToRefundTimeout → Cancelled

Reembolso completo: 1000 USDT devueltos

Caso 14: Comprador Envía Fiat → Vendedor No Confirma → Disputa 🔥
Flujo: Pago legítimo → Vendedor ausente → Protección del comprador

Pasos:

Estado: Funded (independiente de quién inició)

Comprador envía fiat con pruebas

Vendedor no responde (problema personal, técnico, etc.)

Comprador protege sus intereses: raiseDispute(escrowId, "Pago enviado, vendedor no responde")

Estado: Funded → Disputed

Arbitraje resuelve basado en evidencia

Caso 15: Solicitud de Reembolso → Comprador Disputa Legítimamente 🔥
Flujo: Vendedor pide reembolso → Comprador demuestra pago → Arbitraje

Pasos:

Vendedor (que depositó al proponer) solicita: requestRefund(escrowId)

Comprador tiene evidencia de pago: raiseDispute(escrowId, "Transferencia enviada: evidencia")

Estado: ToRefundTimeout → Disputed

Arbitraje evalúa:

¿Comprador realmente envió fiat?

¿Vendedor realmente lo recibió?

¿Hay problemas bancarios legítimos?

Resolución: Fondos al ganador según evidencia

Caso 16: Problema Bancario con Fondos Pre-depositados 🏦
Flujo: Vendedor ya depositó → Pago fiat retenido por banco → Manejo colaborativo

Pasos:

Estado: Funded (vendedor depositó al proponer)

Comprador envía fiat pero banco lo retiene por verificación

Vendedor no recibe y legítimamente solicita reembolso

Comprador disputa con evidencia bancaria válida

Arbitraje reconoce problema bancario legítimo

Resolución:

Tiempo extendido para resolución bancaria

O acuerdo de método de pago alternativo

Fondos permanecen seguros durante resolución

CASOS ESPECIALES DE SEGURIDAD
Protección Integral Implementada 🛡️
El sistema incluye protección completa contra:

Propuestas no autorizadas: Víctimas pueden rechazar sin riesgo

Términos incorrectos: Corrección mediante rechazo y nueva propuesta

Múltiples propuestas: Gestión flexible de ofertas simultáneas

Ataques de drenaje: Prevención mediante reputación y costos reales

Spam malicioso: Costo de gas disuade comportamiento abusivo

Resultado: Protección robusta manteniendo flexibilidad operativa.

--- Cero riesgo, protección total

Caso 17: Propuesta con Términos Incorrectos → Corrección 🔄
Flujo: Error en propuesta → Rechazo → Nueva propuesta correcta

Pasos:

Iniciador se equivoca en términos (monto, moneda, etc.)

Contraparte detecta error: rejectProposal(escrowId, "Error en términos")

Iniciador crea nueva propuesta con términos correctos

Aceptación de propuesta corregida

Flujo continúa normalmente

Caso 18: Múltiples Propuestas Simultáneas 🔄
Flujo: Ambas partes proponen al mismo tiempo → Gestión de duplicados

Pasos:

Vendedor crea propuesta A

Comprador simultáneamente crea propuesta B con términos similares

Ambos ven las dos propuestas

Decisión:

Aceptan una y cancelan/rechazan la otra

O rechazan ambas y crean una nueva acordada

Resultado: Flexibilidad sin conflictos

VENTAJAS DEL SISTEMA BIDIRECCIONAL
🔄 Flexibilidad de Iniciativa
Vendedor puede iniciar: "Tengo crypto, busco fiat"

Comprador puede iniciar: "Necesito crypto, tengo fiat"

Igualdad de roles: Ambos pueden ser proactivos

🤝 Mejora de UX
Iniciativa natural: Quien tiene urgencia propone primero

Proceso simétrico: Mismas funciones para ambas partes

Negociación equilibrada: Sin ventaja por rol

🛡️ Seguridad Mantenida
Consentimiento mutuo: Siempre requerido independiente del iniciador

Sin fondos en riesgo: Durante toda la fase de propuesta

Protección igual: Para iniciador y receptor

 

Este diseño bidireccional mantiene toda la seguridad mientras mejora significativamente la flexibilidad y eficiencia del marketplace P2P.