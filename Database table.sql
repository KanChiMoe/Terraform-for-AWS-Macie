CREATE EXTERNAL TABLE Discord_Messages (
    `data` struct<
        id:INT,
        channel_id:INT, 
        guild_id:INT,
        content:string,
    >,
    `author` struct<
        id:INT,
        username:string,
        discriminator:string,
    >
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'


