select
        [AvailabilityGroupName]     = AG.name,
        [PrimaryReplicaServerName]  = isnull(agstates.primary_replica, ''),
        [LocalReplicaRole]          = isnull(arstates.role, 3),
        [DatabaseName]              = dbcs.database_name,
        [SynchronizationState]      = isnull(dbrs.synchronization_state, 0),
        [IsSuspended]               = isnull(dbrs.is_suspended, 0),
        [IsJoined]                  = isnull(dbcs.is_database_joined, 0)
from    master.sys.availability_groups as AG
        LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates on AG.group_id = agstates.group_id
        INNER JOIN master.sys.availability_replicas as AR on AG.group_id = AR.group_id
        INNER JOIN master.sys.dm_hadr_availability_replica_states as arstates on AR.replica_id = arstates.replica_id AND arstates.is_local = 1
        INNER JOIN master.sys.dm_hadr_database_replica_cluster_states as dbcs  on arstates.replica_id = dbcs.replica_id
        LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states as dbrs on dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
order by AG.name asc, dbcs.database_name