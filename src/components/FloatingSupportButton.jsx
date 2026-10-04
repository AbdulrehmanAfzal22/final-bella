import {MessageCircle} from 'lucide-react';
import {Link} from 'react-router-dom';
import './FloatingSupportButton.css';

export default function FloatingSupportButton(){
  return <Link className="floating-support-button" to="/contact-support" aria-label="Contact the Bella by RT studio">
    <MessageCircle size={19} strokeWidth={1.7} aria-hidden="true"/>
    <span>Contact the studio</span>
  </Link>;
}