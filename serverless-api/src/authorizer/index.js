const { DynamoDBClient, GetItemCommand } = require("@aws-sdk/client-dynamodb");

const client = new DynamoDBClient({});

/**
 * REST API TOKEN authorizer: Authorization header value must match a row in auth_table (PK token).
 */
exports.handler = async (event) => {
  const headerValue = event.authorizationToken;
  if (!headerValue || typeof headerValue !== "string") {
    throw new Error("Unauthorized");
  }

  const token = headerValue.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    throw new Error("Unauthorized");
  }

  const tableName = process.env.AUTH_TABLE_NAME;
  const out = await client.send(
    new GetItemCommand({
      TableName: tableName,
      Key: { token: { S: token } },
    })
  );

  if (!out.Item) {
    throw new Error("Unauthorized");
  }

  return {
    principalId: "user",
    policyDocument: {
      Version: "2012-10-17",
      Statement: [
        {
          Action: "execute-api:Invoke",
          Effect: "Allow",
          Resource: event.methodArn,
        },
      ],
    },
    context: {
      token: token,
    },
  };
};
