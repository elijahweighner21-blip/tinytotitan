--!strict
--[[
	ReceiptLedger
	Idempotency for Developer Product receipts. The ledger lives inside the
	player's save (Monetization.Receipts: PurchaseId -> unix time) so it moves
	with the player across servers and is written atomically with the reward.

	ProcessReceipt flow (MonetizationService):
	  1. ledger has PurchaseId          -> PurchaseGranted (never grant twice)
	  2. grant reward in memory, record PurchaseId in the same data
	  3. force-save with UpdateAsync    -> success: PurchaseGranted
	                                      failure: NotProcessedYet (Roblox retries;
	                                      step 1 prevents a double grant if the
	                                      in-memory profile already has it)
]]

local ReceiptLedger = {}

export type Ledger = { [string]: number }

function ReceiptLedger.has(ledger: Ledger, purchaseId: string): boolean
	return ledger[purchaseId] ~= nil
end

function ReceiptLedger.record(ledger: Ledger, purchaseId: string, now: number)
	ledger[purchaseId] = now
end

-- Keeps the newest `max` entries.
function ReceiptLedger.prune(ledger: Ledger, max: number)
	local entries = {}
	for id, t in ledger do
		table.insert(entries, { id = id, t = t })
	end
	if #entries <= max then
		return
	end
	table.sort(entries, function(a, b)
		return a.t < b.t
	end)
	for i = 1, #entries - max do
		ledger[entries[i].id] = nil
	end
end

return ReceiptLedger
