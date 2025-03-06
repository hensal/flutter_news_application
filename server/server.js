const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const bodyParser = require('body-parser');
const nodemailer = require('nodemailer');
const multer = require('multer');
require('dotenv').config();
const { body, validationResult } = require('express-validator');

// Load the JWT_SECRET from environment variables
const JWT_SECRET = process.env.JWT_SECRET; 

const app = express();
app.use(cors());
app.use(bodyParser.json());

const upload = multer({ limits: { fileSize: 50 * 1024 * 1024 } }); // 50

const PORT = 3000;
// PostgreSQL Connection Pool
const pool = new Pool({
  user: 'postgres', 
  host: 'localhost',
  database: 'flutter',
  password: 'password',         
  port: 5433,
});

// Middleware to verify JWT token

const authenticateUser = (req, res, next) => {
  const token = req.headers['authorization']?.split(' ')[1]; 

  if (!token) {
    return res.status(401).json({ error: 'No token provided, user not authenticated' });
  }

  try {
    // Verify and decode the token using the secret key
    const decoded = jwt.verify(token, process.env.JWT_SECRET);  // Use your secret key here
    req.user = decoded;  // Add decoded user data to request object
    next();  // Continue to the next middleware or route handler
  } catch (err) {
    console.error('Invalid or expired token:', err);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};

// Fetch user details
app.get('/user-info', async (req, res) => {
  try {
      const userId = req.query.userId;
      console.log("User ID received: ", userId); // Debugging
      if (!userId) {
          return res.status(400).json({ error: 'User ID is required' });
      }

      // Query the database using the pool
      const { rows } = await pool.query('SELECT * FROM Users WHERE id = $1', [userId]);

      console.log("User Data: ", rows); // Debugging
      if (rows.length === 0) {
          return res.status(404).json({ error: 'User not found' });
      }

      res.json(rows[0]); // Send the first row (user)
  } catch (error) {
      console.error("Server Error: ", error);
      res.status(500).json({ error: 'Server error' });
  }
});


// **Register User API with Gmail Validation**
app.post(
  '/register',
  [
    body('name').notEmpty().withMessage('Name is required'),
    body('email')
      .matches(/^[a-zA-Z0-9._%+-]+@gmail\.com$/)
      .withMessage('Only Gmail addresses are allowed'),
    body('password')
      .isLength({ min: 5 })
      .withMessage('Password must be at least 5 characters long'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { name, email, password } = req.body;

    try {
      // Check if user already exists
      const userExists = await pool.query('SELECT * FROM Users WHERE email = $1', [email]);
      if (userExists.rows.length > 0) {
        return res.status(400).json({ message: 'Email already in use.' });
      }

      // Hash password before saving
      const hashedPassword = await bcrypt.hash(password, 10);

      // Insert user into the database
      const newUser = await pool.query(
        'INSERT INTO Users (name, email, password) VALUES ($1, $2, $3) RETURNING *',
        [name, email, hashedPassword]
      );

      res.status(201).json({ message: 'User registered successfully', user: newUser.rows[0] });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error' });
    }
  }
);

// Login Route 
app.post('/login', async (req, res) => {
  const { email, password } = req.body;

  try {
      const userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);

      if (userResult.rows.length === 0) {
          return res.status(401).json({ success: false, message: 'Invalid credentials' });
      }

      const user = userResult.rows[0];
      const passwordMatch = await bcrypt.compare(password, user.password);

      if (!passwordMatch) {
          return res.status(401).json({ success: false, message: 'Invalid credentials' });
      }

      // Generate JWT token
      const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET);

      // Save token in the database
      await pool.query('UPDATE users SET token = $1 WHERE id = $2', [token, user.id]);

      res.json({ success: true, message: 'Login successful', token, userId: user.id }); // Include userId
  } catch (error) {
      console.error(error); // Log the error for debugging
      res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
});


// Create a Nodemailer transporter using Gmail
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
  tls: {
    rejectUnauthorized: false, 
  },
});   

// Password reset route
app.post('/send-reset-link', async (req, res) => {
  const { email } = req.body;

  // Check if email is valid
  if (!email || !email.includes('@gmail.com')) {
    return res.status(400).json({ message: 'Invalid email address' });
  }

  try {
    // Check if the email exists in the database
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'We cannot find your email, re-check your email!!!' });
    }

    // Generate the reset URL
    const resetUrl = `http://localhost:60966/reset-password?email=${email}`;

    // Create the mailOptions object to send the reset link
    const mailOptions = {
      from: process.env.EMAIL_USER, // The email from which the reset link will be sent
      to: email, // Send to the email that requested the reset
      subject: 'Password Reset Request',
      text: `Hello, you can reset your password here: ${resetUrl}`, 
    };

    // Send email to the requested user
    await transporter.sendMail(mailOptions);

    return res.status(200).json({ message: 'Password reset link sent!' });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ message: 'Error sending email', error: error.message });
  }
});

// Route to reset password (this is just a placeholder)
app.post('/reset-password', async (req, res) => {
  const { email, newPassword } = req.body;

  if (!newPassword || newPassword.length < 5) {
    return res.status(400).json({ success: false, message: 'Password must be at least 5 characters long.' });
  }

  try {
    // Hash the new password before saving
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update password in the database
    const result = await pool.query('UPDATE users SET password = $1 WHERE email = $2', [hashedPassword, email]);

    // Check if any rows were updated
    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Generate new JWT token
    const userResult = await pool.query('SELECT id, email FROM users WHERE email = $1', [email]);
    const user = userResult.rows[0];

    const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '1h' });

    return res.status(200).json({
      success: true,
      message: 'Password has been reset successfully.',
      token: token
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: 'Error resetting password' });
  }
});

// API to add news with image
app.post("/news", upload.single('image'), async (req, res) => {
  const { title, description, category } = req.body;
  const image = req.file; // Access image file via req.file

  if (!image) {
    return res.status(400).json({ error: "Image is required" });
  }

  try {
    const imageBuffer = image.buffer; // Access image buffer
    const result = await pool.query(
      "INSERT INTO news (title, description, category, image_url) VALUES ($1, $2, $3, $4) RETURNING *",
      [title, description, category, imageBuffer]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// API to retrieve news with images
app.get("/news", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT news.id, news.title, news.description, news.category, 
              news.published_at, encode(news.image_url, 'base64') AS image,
              COALESCE(CAST(like_counts.total_likes AS INTEGER), 0) AS like_count
       FROM news
       LEFT JOIN (
          SELECT news_id, COUNT(*) AS total_likes 
          FROM likes 
          GROUP BY news_id
       ) AS like_counts
       ON news.id = like_counts.news_id
       ORDER BY news.published_at DESC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

app.get("/news1", async (req, res) => {
  const category = req.query.category; // Get the category from query parameter

  try {
    // If category is provided, filter case-insensitively; otherwise, fetch all news
    const query = category
      ? `SELECT id, title, description, category, published_at, encode(image_url, 'base64') AS image
         FROM news
         WHERE category ILIKE $1 AND published_at <= NOW()`
      : `SELECT id, title, description, category, published_at, encode(image_url, 'base64') AS image
         FROM news
         WHERE published_at <= NOW()`;
      
    const values = category ? [category] : [];

    const result = await pool.query(query, values);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

app.get("/news-search", async (req, res) => {
  const searchQuery = req.query.search || ''; // Default to empty string

  console.log("Received search query:", searchQuery); // ✅ Debug Log

  try {
    if (searchQuery.trim() === '') {
      // Handle empty query, maybe return all news or a message
      return res.status(400).json({ message: 'Search query cannot be empty.' });
    }

    const result = await pool.query(
      `SELECT id, title, description, category, published_at, encode(image_url, 'base64') AS image
       FROM news
       WHERE title ILIKE $1 OR description ILIKE $1`,
      [`%${searchQuery}%`] // Pass wildcard inside JavaScript
    );

    console.log("Database query result:", result.rows); // ✅ Debug Log

    res.json(result.rows);
  } catch (err) {
    console.error("Database error:", err);
    res.status(500).json({ error: "Database error" });
  }
});

// Like/unlike news route
app.post("/like-news", authenticateUser, async (req, res) => {
  try {
    const { news_id } = req.body;
    const userId = req.user.id; // Get user ID from the decoded token

    // Check if the user has already liked this news
    const existingLike = await pool.query(
      "SELECT * FROM likes WHERE news_id = $1 AND user_id = $2",
      [news_id, userId]
    );

    if (existingLike.rows.length > 0) {
      // If the user has already liked, remove the like (unlike)
      await pool.query(
        "DELETE FROM likes WHERE news_id = $1 AND user_id = $2",
        [news_id, userId]
      );

      // Decrease the `like_count` in the `news` table (ensure it doesn't go negative)
      await pool.query(
        "UPDATE news SET like_count = GREATEST(like_count - 1, 0) WHERE id = $1", // Prevent going below 0
        [news_id]
      );

      // Return the updated like count
      const result = await pool.query(
        "SELECT like_count FROM news WHERE id = $1",
        [news_id]
      );
      const likeCount = result.rows[0].like_count;

      res.json({ success: true, likeCount, action: 'unliked' }); // Action is 'unliked'
    } else {
      // If the user hasn't liked yet, insert the like
      await pool.query(
        "INSERT INTO likes (news_id, user_id) VALUES ($1, $2) ON CONFLICT(news_id, user_id) DO NOTHING",
        [news_id, userId]
      );

      // Increase the `like_count` in the `news` table
      await pool.query(
        "UPDATE news SET like_count = like_count + 1 WHERE id = $1",
        [news_id]
      );

      // Return the updated like count
      const result = await pool.query(
        "SELECT like_count FROM news WHERE id = $1",
        [news_id]
      );
      const likeCount = result.rows[0].like_count;

      res.json({ success: true, likeCount, action: 'liked' }); // Action is 'liked'
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

app.get('/check-like', async (req, res) => {
  try {
    const { userId, newsId } = req.query;

    if (!userId || !newsId) {
      return res.status(400).json({ error: 'userId and newsId are required' });
    }

    const query = 'SELECT * FROM likes WHERE user_id = $1 AND news_id = $2';
    const result = await pool.query(query, [userId, newsId]);

    if (result.rows.length > 0) {
      // User has liked the news
      return res.json({ liked: true });
    } else {
      // User has not liked the news
      return res.json({ liked: false });
    }
  } catch (error) {
    console.error("Error checking like status:", error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST endpoint to add a comment

app.post('/comments', authenticateUser, async (req, res) => {
  const { news_id, comment_text } = req.body;

  // Now the user ID is available in req.user (from the token)
  const user_id = req.user.id;

  try {
    // Begin a transaction
    await pool.query('BEGIN');

    // Insert the comment into the comments table
    const result = await pool.query(
      'INSERT INTO comments (user_id, news_id, comment_text) VALUES ($1, $2, $3) RETURNING *',
      [user_id, news_id, comment_text]
    );

    // Get the newly inserted comment's ID (result.rows[0].comment_id)
    const commentId = result.rows[0].comment_id;

    // Increment the comment count in the news table
    await pool.query(
      'UPDATE news SET comment_count = comment_count + 1 WHERE id = $1',
      [news_id]
    );

    // Commit the transaction
    await pool.query('COMMIT');

    // Respond back with the comment data
    res.status(200).json({
      message: 'Comment added',
      comment: result.rows[0],
      comment_id: commentId,  // Send back the new comment's ID
    });
  } catch (error) {
    // Rollback if there's an error
    await pool.query('ROLLBACK');
    console.error('Error adding comment:', error);
    res.status(500).json({ message: 'Failed to add comment' });
  }
}); 

app.get('/comments/:newsId', async (req, res) => {
  const newsId = req.params.newsId;

  try {
    const query = `
      SELECT c.id, c.comment_text, c.created_at, u.id AS user_id, u.name AS user_name
      FROM comments c
      JOIN users u ON c.user_id = u.id
      WHERE c.news_id = $1
      ORDER BY c.created_at DESC
    `;
    const result = await pool.query(query, [newsId]);

    res.json({
      success: true,
      comments: result.rows,
    });
  } catch (error) {
    console.error('Error fetching comments:', error);
    res.status(500).json({ success: false, message: 'Error fetching comments' });
  }
});

// DELETE endpoint to delete a comment
app.delete('/comments/:commentId', async (req, res) => {
  const { commentId } = req.params;
  const { userId } = req.body; // Make sure this comes from the body

  // Check that the userId is valid and that it matches the comment's author
  try {
    const commentQuery = 'SELECT * FROM comments WHERE id = $1';
    const commentResult = await pool.query(commentQuery, [commentId]);

    if (commentResult.rows.length === 0) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    const comment = commentResult.rows[0];

    if (comment.user_id !== userId) {
      return res.status(403).json({ message: 'You are not authorized to delete this comment' });
    }

    const deleteQuery = 'DELETE FROM comments WHERE id = $1';
    await pool.query(deleteQuery, [commentId]);

    return res.status(200).json({ message: 'Comment deleted successfully' });
  } catch (error) {
    console.error('Error deleting comment:', error);
    return res.status(500).json({ message: 'An error occurred while deleting the comment' });
  }
});

// PUT endpoint to update a comment
app.put('/comments/:commentId', async (req, res) => {
  const { commentId } = req.params;
  const { userId, newCommentText } = req.body; // Get userId and new comment text from the request body

  try {
    // Query the comment to check if it exists
    const commentQuery = 'SELECT * FROM comments WHERE id = $1';
    const commentResult = await pool.query(commentQuery, [commentId]);

    if (commentResult.rows.length === 0) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    const comment = commentResult.rows[0];

    // Ensure that the logged-in user is the author of the comment
    if (comment.user_id !== userId) {
      return res.status(403).json({ message: 'You are not authorized to edit this comment' });
    }

    // Update the comment text in the database
    const updateQuery = 'UPDATE comments SET comment_text = $1 WHERE id = $2';
    await pool.query(updateQuery, [newCommentText, commentId]);

    return res.status(200).json({ message: 'Comment updated successfully' });
  } catch (error) {
    console.error('Error updating comment:', error);
    return res.status(500).json({ message: 'An error occurred while updating the comment' });
  }
});


// Start Server
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
