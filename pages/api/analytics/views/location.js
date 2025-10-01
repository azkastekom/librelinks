import axios from 'axios';

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).end();
  }

  try {
    const { handle } = req.query;
    const endpoint = `${process.env.ANALYTICS_BASE_URL}/v0/pipes/libre_location_tracking.json`;

    if (!handle || typeof handle !== 'string') {
      return res.status(404).end();
    }

    const analytics = await axios.get(
      `${endpoint}?token=${process.env.LOCATION_ANALYTICS_TOKEN}&handle=/${handle}`
    );

    return res.status(200).json(analytics.data.data);
  } catch (error) {
    console.log(error);
    return res.status(500).end();
  }
}
