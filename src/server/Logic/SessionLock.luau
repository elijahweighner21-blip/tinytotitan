--!strict
--[[
	SessionLock
	Pure decision logic for DataStore session locking (kept free of Roblox
	services so it is unit-tested). A record stored in the DataStore looks like:

	  { Data = <player data>, Session = { JobId, PlaceId, Time } | nil, SavedAt }

	A server may write a record only if it owns the session, nobody does, or
	the owner's lock is stale (its server crashed and stopped refreshing it).
]]

export type Session = { JobId: string, PlaceId: number, Time: number }

local SessionLock = {}

function SessionLock.isStale(session: Session?, now: number, timeout: number): boolean
	if not session then
		return true
	end
	return now - (session.Time or 0) > timeout
end

-- Can `jobId` take/keep the lock on this record right now?
function SessionLock.canClaim(session: Session?, jobId: string, now: number, timeout: number): (boolean, string)
	if session == nil then
		return true, "free"
	end
	if session.JobId == jobId then
		return true, "owned"
	end
	if SessionLock.isStale(session, now, timeout) then
		return true, "stale"
	end
	return false, "locked"
end

function SessionLock.make(jobId: string, placeId: number, now: number): Session
	return { JobId = jobId, PlaceId = placeId, Time = now }
end

-- Old saves were stored as the raw data table. Wrap them transparently.
function SessionLock.unwrap(record: any): (any, Session?)
	if type(record) ~= "table" then
		return nil, nil
	end
	if record.Data ~= nil or record.Session ~= nil or record.SavedAt ~= nil then
		return record.Data, record.Session
	end
	return record, nil
end

return SessionLock
