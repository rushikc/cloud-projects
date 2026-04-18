const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");

const client = new DynamoDBClient({});

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body),
});

/**
 * POST /data — body: { "id": "<string>", "attributes": { ... optional map } }
 * Stores id and optional string attributes (serialized) on the item.
 */
exports.handler = async (event) => {
  let body;
  try {
    body = JSON.parse(event.body || "{}");
  } catch {
    return json(400, { message: "Invalid JSON body" });
  }

  const id = body.id;
  if (!id || typeof id !== "string") {
    return json(400, { message: "Field id (string) is required" });
  }

  const tableName = process.env.DATA_TABLE_NAME;
  const item = { id: { S: id } };

  if (body.attributes && typeof body.attributes === "object" && !Array.isArray(body.attributes)) {
    item.attributes = { S: JSON.stringify(body.attributes) };
  }

  await client.send(
    new PutItemCommand({
      TableName: tableName,
      Item: item,
    })
  );

  return json(200, { ok: true, id });
};
