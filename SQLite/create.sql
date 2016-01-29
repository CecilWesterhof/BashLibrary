CREATE  TABLE directoryUsage(
    date        TEXT  DEFAULT CURRENT_DATE NOT NULL,
    directory   TEXT  NOT NULL,
    used        TEXT  NOT NULL,

    PRIMARY KEY(date, directory)
);
CREATE  TABLE partitionUsage(
    date        TEXT  DEFAULT CURRENT_DATE NOT NULL,
    partition   TEXT  NOT NULL,
    size        TEXT  NOT NULL,
    used        TEXT  NOT NULL,
    available   TEXT  NOT NULL,
    percentUsed TEXT  NOT NULL,

    PRIMARY KEY(date, partition)
);
CREATE TABLE variables (
	name        TEXT NOT NULL,
	value	    TEXT NOT NULL,

	PRIMARY KEY(name)
);
