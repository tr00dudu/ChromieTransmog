local Transmog = _G.ChromieTransmog

Transmog.availableTransmogItems = {}
Transmog.ItemButtons = {}
Transmog.currentTransmogSlotName = nil
Transmog.currentTransmogSlot = nil
Transmog.currentTransmogItemClass = nil
Transmog.currentPage = 1
Transmog.totalPages = 1
Transmog.ipp = 15
Transmog.numTransmogs = {}
Transmog.transmogDataFromServer = {}
Transmog.transmogStatusFromServer = {}
Transmog.transmogStatusToServer = {}
Transmog.tab = ''
Transmog.equippedItems = {}
Transmog.currentOutfit = nil
Transmog.chromieSets = {}
Transmog.chromieSetItems = {}
Transmog.chromiePendingSet = nil
Transmog.equippedTransmogs = {}
Transmog.transmogGossipIcon = {}
-- Session dummy state. Gossip does not send real ids for already-applied mogs
-- (UNKNOWN_MOG); those stay -1 until the player picks or applies one.
Transmog.previewShown = {}
Transmog.previewBaseline = {}
Transmog.applied = {}
Transmog.appliedIcon = {}
