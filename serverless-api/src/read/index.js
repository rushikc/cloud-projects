const { DynamoDBClient, GetItemCommand } = require("@aws-sdk/client-dynamodb");
const { unmarshall } = require("@aws-sdk/util-dynamodb");

const client = new DynamoDBClient({});

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body),
});

/**
 * GET /data?id=... — returns the DynamoDB item (unmarshalled) or 404.
 */
exports.handler = async (event) => {
  const id = event.queryStringParameters?.id;
  if (!id) {
    return json(400, { message: "Query parameter id is required" });
  }

  const tableName = process.env.DATA_TABLE_NAME;
  const out = await client.send(
    new GetItemCommand({
      TableName: tableName,
      Key: { id: { S: id } },
    })
  );

  if (!out.Item) {
    return json(404, { message: "Not found" });
  }

  return json(200, { item: unmarshall(out.Item) });
};
