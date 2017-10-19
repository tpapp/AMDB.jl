using FlexDates

export AMDB_Date

const EPOCH = Date(2000,1,1)    # all dates relative to this

const AMDB_Date = FlexDate{EPOCH,Int16} # should be enough for everything
